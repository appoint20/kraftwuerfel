#!/usr/bin/env python3
"""
Erzeugt Kraftwuerfel.xcodeproj/project.pbxproj aus dem Dateibaum.

Warum ein Generator statt einer gepflegten project.pbxproj:

Die alte Projektdatei stammte aus einem Capacitor-Gerüst von 2018
(objectVersion 48) und wurde danach von Hand weitergeschrieben — mit
ausgedachten Objekt-IDs wie 504EC8001FED796500000001, die aussehen wie
Xcode-IDs, aber durchgezählt waren. Eine Datei zu drei Zielen hinzuzufügen
heißt dort, an sechs Stellen konsistent zu editieren. Genau so entstehen die
Fehler, die dieses Projekt hatte: WatchContentView.swift hing in den Sources
des iPhone-Ziels, und für die Live Activity gab es überhaupt kein Ziel.

Hier steht die Zielstruktur einmal als Daten, und die IDs kommen deterministisch
aus dem Pfad. Eine neue Datei anlegen, Skript laufen lassen, fertig:

    python3 Tools/generate_xcodeproj.py

Die erzeugte project.pbxproj wird eingecheckt — Xcode braucht das Skript nicht.

Notausgang für Rechner ohne watchOS-Plattform:

    KRAFT_SKIP_WATCH=1 python3 Tools/generate_xcodeproj.py

`actool` verlangt eine installierte watchsimulator-Laufzeit, sobald ein
watchOS-Ziel im Projekt steht — auch beim Bauen fürs Gerät. Fehlt sie, lässt
sich das Projekt sonst überhaupt nicht übersetzen. Die Fassung ohne Uhr ist
ausschließlich zum Prüfen von App und Widget gedacht; was in den Store geht,
wird IMMER ohne diese Variable erzeugt.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT_NAME = "Kraftwuerfel"
XCODEPROJ = ROOT / f"{PROJECT_NAME}.xcodeproj"

TEAM = "NDK6BWT4SW"
APP_BUNDLE_ID = "app.kraftwuerfel"
WIDGET_BUNDLE_ID = f"{APP_BUNDLE_ID}.LiveActivity"
WATCH_BUNDLE_ID = f"{APP_BUNDLE_ID}.watchkitapp"

IOS_DEPLOYMENT_TARGET = "16.2"   # ActivityContent/ActivityConfiguration
WATCHOS_DEPLOYMENT_TARGET = "10.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.0"
CURRENT_PROJECT_VERSION = "1"

APP_DIR = "Kraftwuerfel"
WIDGET_DIR = "KraftwuerfelWidget"
WATCH_DIR = "KraftwuerfelWatch"
TEST_DIR = "KraftwuerfelTests"

# Dateien der App, die zusätzlich in andere Ziele übersetzt werden.
# WorkoutActivityAttributes MUSS in App und Erweiterung stehen: ActivityKit
# gleicht den Typ über den Namen ab, eine Kopie liefe beim ersten Feldwechsel
# auseinander und die Karte bliebe leer.
SHARED_WITH_WIDGET = {
    f"{APP_DIR}/Shared/WorkoutActivityAttributes.swift",
    f"{APP_DIR}/Theme/Theme.swift",
    f"{APP_DIR}/Theme/KraftFont.swift",
    # Die Karte übersetzt sich selbst — die Sprache kommt im ContentState mit,
    # denn die Erweiterung hat eigene UserDefaults und läse dort immer "de".
    f"{APP_DIR}/Shared/Strings.swift",
}
SHARED_WITH_WATCH = {
    f"{APP_DIR}/Theme/Theme.swift",
    f"{APP_DIR}/Theme/KraftFont.swift",
    f"{APP_DIR}/Services/WatchSyncManager.swift",
}

FONT_DIR = f"{APP_DIR}/Fonts"

# Siehe Modulkommentar: nur zum Prüfen auf Rechnern ohne watchOS-Plattform.
SKIP_WATCH = os.environ.get("KRAFT_SKIP_WATCH") == "1"


# ---------------------------------------------------------------- IDs

def oid(*parts: str) -> str:
    """Deterministische 24-stellige Objekt-ID. Gleicher Pfad -> gleiche ID,
    also erzeugt ein erneuter Lauf keinen Rausch im Diff."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


def quote(value: str) -> str:
    safe = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./$")
    if value and all(c in safe for c in value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".h": "sourcecode.c.h",
    ".m": "sourcecode.c.objc",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcassets": "folder.assetcatalog",
    ".xcprivacy": "text.plist.xml",
    ".storyboard": "file.storyboard",
    ".ttf": "file",
    ".otf": "file",
    ".json": "text.json",
    ".png": "image.png",
}


def file_type(name: str) -> str:
    return FILE_TYPES.get(Path(name).suffix, "text")


# ---------------------------------------------------------------- Baum

class Node:
    """Ein Eintrag im Projektnavigator."""

    def __init__(self, name: str, path: str, is_dir: bool):
        self.name = name
        self.path = path              # relativ zum Projektstamm
        self.is_dir = is_dir
        self.children: list[Node] = []

    @property
    def uuid(self) -> str:
        return oid("group" if self.is_dir else "file", self.path)


SKIP_NAMES = {".DS_Store"}
# Als eine Einheit referenziert, nicht als Ordner aufgeklappt.
OPAQUE_SUFFIXES = {".xcassets"}


def build_tree(rel_dir: str) -> Node:
    node = Node(Path(rel_dir).name, rel_dir, True)
    abs_dir = ROOT / rel_dir

    for entry in sorted(os.listdir(abs_dir), key=lambda s: (not (abs_dir / s).is_dir(), s.lower())):
        if entry in SKIP_NAMES:
            continue
        rel = f"{rel_dir}/{entry}"
        abs_path = abs_dir / entry

        if abs_path.is_dir() and Path(entry).suffix in OPAQUE_SUFFIXES:
            node.children.append(Node(entry, rel, False))
        elif abs_path.is_dir():
            if entry == "Base.lproj":      # als Variantengruppe behandelt
                continue
            node.children.append(build_tree(rel))
        else:
            node.children.append(Node(entry, rel, False))
    return node


def walk_files(node: Node):
    for child in node.children:
        if child.is_dir:
            yield from walk_files(child)
        else:
            yield child


# ---------------------------------------------------------------- Ziele

class Target:
    def __init__(self, name: str, product_type: str, product_name: str):
        self.name = name
        self.product_type = product_type
        self.product_name = product_name
        self.sources: list[str] = []     # relative Pfade
        self.resources: list[str] = []
        self.dependencies: list[Target] = []

    @property
    def uuid(self) -> str:
        return oid("target", self.name)

    @property
    def product_uuid(self) -> str:
        return oid("product", self.name)

    def build_file(self, rel: str) -> str:
        return oid("buildfile", self.name, rel)


def collect(app_tree: Node, widget_tree: Node, watch_tree: Node, test_tree: Node):
    app = Target(PROJECT_NAME, "com.apple.product-type.application", f"{PROJECT_NAME}.app")
    widget = Target(WIDGET_DIR, "com.apple.product-type.app-extension", f"{WIDGET_DIR}.appex")
    watch = Target(WATCH_DIR, "com.apple.product-type.application", f"{WATCH_DIR}.app")
    tests = Target(TEST_DIR, "com.apple.product-type.bundle.unit-test", f"{TEST_DIR}.xctest")

    fonts = sorted(
        f"{FONT_DIR}/{f}" for f in os.listdir(ROOT / FONT_DIR) if f.endswith((".ttf", ".otf"))
    )

    for node in walk_files(app_tree):
        rel, suffix = node.path, Path(node.name).suffix
        if suffix == ".swift":
            app.sources.append(rel)
            if rel in SHARED_WITH_WIDGET:
                widget.sources.append(rel)
            if rel in SHARED_WITH_WATCH:
                watch.sources.append(rel)
        elif suffix in (".xcassets", ".xcprivacy"):
            app.resources.append(rel)
        # Info.plist und .entitlements gehören in Build-Settings, nicht in eine
        # Kopierphase — sonst landen sie zusätzlich als lose Datei im Bündel.

    app.resources.extend(fonts)
    widget.resources.extend(fonts)
    watch.resources.extend(fonts)

    for node in walk_files(widget_tree):
        if Path(node.name).suffix == ".swift":
            widget.sources.append(node.path)

    for node in walk_files(watch_tree):
        rel, suffix = node.path, Path(node.name).suffix
        if suffix == ".swift":
            watch.sources.append(rel)
        elif suffix == ".xcassets":
            watch.resources.append(rel)

    for node in walk_files(test_tree):
        if Path(node.name).suffix == ".swift":
            tests.sources.append(node.path)

    app.dependencies = [widget] if SKIP_WATCH else [widget, watch]
    # Die Tests hängen an der App, nicht umgekehrt — sonst gäbe es einen Zyklus.
    tests.dependencies = [app]

    for t in (app, widget, watch, tests):
        t.sources = sorted(set(t.sources))
        t.resources = sorted(set(t.resources))
    return app, widget, watch, tests


# ---------------------------------------------------------------- Settings

COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": IOS_DEPLOYMENT_TARGET,
    "WATCHOS_DEPLOYMENT_TARGET": WATCHOS_DEPLOYMENT_TARGET,
    "SDKROOT": "iphoneos",
    "SWIFT_VERSION": SWIFT_VERSION,
}

PROJECT_DEBUG = dict(COMMON, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf",
    "ENABLE_TESTABILITY": "YES",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "GCC_PREPROCESSOR_DEFINITIONS": ("DEBUG=1", "$(inherited)"),
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
    "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
})

PROJECT_RELEASE = dict(COMMON, **{
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO",
    "SWIFT_COMPILATION_MODE": "wholemodule",
    "VALIDATE_PRODUCT": "YES",
})

APP_SETTINGS = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "CODE_SIGN_ENTITLEMENTS": f"{APP_DIR}/{PROJECT_NAME}.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES",
    "INFOPLIST_FILE": f"{APP_DIR}/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ("$(inherited)", "@executable_path/Frameworks"),
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": APP_BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1,2",
}

WIDGET_SETTINGS = {
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES",
    "INFOPLIST_FILE": f"{WIDGET_DIR}/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": (
        "$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks",
    ),
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": WIDGET_BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SKIP_INSTALL": "YES",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "1,2",
}

WATCH_SETTINGS = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_ENTITLEMENTS": f"{WATCH_DIR}/{WATCH_DIR}.entitlements",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "DEVELOPMENT_TEAM": TEAM,
    "ENABLE_PREVIEWS": "YES",
    "INFOPLIST_FILE": f"{WATCH_DIR}/Info.plist",
    "LD_RUNPATH_SEARCH_PATHS": ("$(inherited)", "@executable_path/Frameworks"),
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": WATCH_BUNDLE_ID,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SDKROOT": "watchos",
    "SKIP_INSTALL": "YES",
    "SUPPORTED_PLATFORMS": "watchsimulator watchos",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "TARGETED_DEVICE_FAMILY": "4",
}


TEST_SETTINGS = {
    "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
    "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": CURRENT_PROJECT_VERSION,
    "DEVELOPMENT_TEAM": TEAM,
    "GENERATE_INFOPLIST_FILE": "YES",
    "MARKETING_VERSION": MARKETING_VERSION,
    "PRODUCT_BUNDLE_IDENTIFIER": f"{APP_BUNDLE_ID}.tests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "NO",
    "TARGETED_DEVICE_FAMILY": "1,2",
    # Die Tests laufen in der App, damit `@testable import Kraftwuerfel` greift.
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Kraftwuerfel.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Kraftwuerfel",
}


def render_settings(settings: dict, indent: str) -> str:
    out = []
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, (tuple, list)):
            out.append(f"{indent}{key} = (")
            for item in value:
                out.append(f"{indent}\t{quote(item)},")
            out.append(f"{indent});")
        else:
            out.append(f"{indent}{key} = {quote(value)};")
    return "\n".join(out)


# ---------------------------------------------------------------- Ausgabe

def generate() -> str:
    app_tree = build_tree(APP_DIR)
    widget_tree = build_tree(WIDGET_DIR)
    watch_tree = build_tree(WATCH_DIR)
    test_tree = build_tree(TEST_DIR)
    app, widget, watch, tests = collect(app_tree, widget_tree, watch_tree, test_tree)
    targets = [app, widget] if SKIP_WATCH else [app, widget, watch]
    targets.append(tests)
    dep_pairs = [(t, d) for t in targets for d in t.dependencies]

    L: list[str] = []
    add = L.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")

    # ---- PBXBuildFile
    add("\n/* Begin PBXBuildFile section */")
    for target in targets:
        for rel in target.sources + target.resources:
            add(f"\t\t{target.build_file(rel)} /* {Path(rel).name} in {target.name} */ = "
                f"{{isa = PBXBuildFile; fileRef = {oid('file', rel)}; }};")
    # LaunchScreen (Variantengruppe) nur in der App
    add(f"\t\t{oid('buildfile', app.name, 'LaunchScreen')} /* LaunchScreen.storyboard in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {oid('variantgroup', 'LaunchScreen')}; }};")
    # Eingebettete Produkte
    add(f"\t\t{oid('embed', 'widget')} /* {widget.product_name} in Embed Foundation Extensions */ = "
        f"{{isa = PBXBuildFile; fileRef = {widget.product_uuid}; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    add(f"\t\t{oid('embed', 'watch')} /* {watch.product_name} in Embed Watch Content */ = "
        f"{{isa = PBXBuildFile; fileRef = {watch.product_uuid}; "
        f"settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};")
    add("/* End PBXBuildFile section */")

    # ---- PBXContainerItemProxy
    add("\n/* Begin PBXContainerItemProxy section */")
    for _, dep in dep_pairs:
        add(f"\t\t{oid('proxy', dep.name)} /* PBXContainerItemProxy */ = {{")
        add("\t\t\tisa = PBXContainerItemProxy;")
        add(f"\t\t\tcontainerPortal = {oid('project')} /* Project object */;")
        add("\t\t\tproxyType = 1;")
        add(f"\t\t\tremoteGlobalIDString = {dep.uuid};")
        add(f"\t\t\tremoteInfo = {dep.name};")
        add("\t\t};")
    add("/* End PBXContainerItemProxy section */")

    # ---- PBXCopyFilesBuildPhase
    add("\n/* Begin PBXCopyFilesBuildPhase section */")
    add(f"\t\t{oid('phase', 'embed-widget')} /* Embed Foundation Extensions */ = {{")
    add("\t\t\tisa = PBXCopyFilesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add('\t\t\tdstPath = "";')
    add("\t\t\tdstSubfolderSpec = 13;")
    add("\t\t\tfiles = (")
    add(f"\t\t\t\t{oid('embed', 'widget')} /* {widget.product_name} */,")
    add("\t\t\t);")
    add('\t\t\tname = "Embed Foundation Extensions";')
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add(f"\t\t{oid('phase', 'embed-watch')} /* Embed Watch Content */ = {{")
    add("\t\t\tisa = PBXCopyFilesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add('\t\t\tdstPath = "$(CONTENTS_FOLDER_PATH)/Watch";')
    add("\t\t\tdstSubfolderSpec = 16;")
    add("\t\t\tfiles = (")
    add(f"\t\t\t\t{oid('embed', 'watch')} /* {watch.product_name} */,")
    add("\t\t\t);")
    add('\t\t\tname = "Embed Watch Content";')
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXCopyFilesBuildPhase section */")

    # ---- PBXFileReference
    add("\n/* Begin PBXFileReference section */")
    seen: set[str] = set()
    trees = [app_tree, widget_tree] if SKIP_WATCH else [app_tree, widget_tree, watch_tree]
    trees.append(test_tree)
    for tree in trees:
        for node in walk_files(tree):
            if node.path in seen:
                continue
            seen.add(node.path)
            add(f"\t\t{node.uuid} /* {node.name} */ = {{isa = PBXFileReference; "
                f"lastKnownFileType = {file_type(node.name)}; path = {quote(node.name)}; "
                f'sourceTree = "<group>"; }};')
    add(f"\t\t{oid('file', f'{APP_DIR}/Base.lproj/LaunchScreen.storyboard')} /* Base */ = "
        "{isa = PBXFileReference; lastKnownFileType = file.storyboard; name = Base; "
        'path = Base.lproj/LaunchScreen.storyboard; sourceTree = "<group>"; };')
    for target in targets:
        add(f"\t\t{target.product_uuid} /* {target.product_name} */ = {{isa = PBXFileReference; "
            f"explicitFileType = {'wrapper.application' if target.product_type.endswith('application') else 'wrapper.app-extension'}; "
            f"includeInIndex = 0; path = {quote(target.product_name)}; sourceTree = BUILT_PRODUCTS_DIR; }};")
    add("/* End PBXFileReference section */")

    # ---- PBXFrameworksBuildPhase (leer: Swift verlinkt automatisch)
    add("\n/* Begin PBXFrameworksBuildPhase section */")
    for target in targets:
        add(f"\t\t{oid('phase', 'frameworks', target.name)} /* Frameworks */ = {{")
        add("\t\t\tisa = PBXFrameworksBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")

    # ---- PBXGroup
    add("\n/* Begin PBXGroup section */")

    def emit_group(node: Node, extra_children: list[str] | None = None):
        add(f"\t\t{node.uuid} /* {node.name} */ = {{")
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        for child in node.children:
            add(f"\t\t\t\t{child.uuid} /* {child.name} */,")
        for extra in extra_children or []:
            add(f"\t\t\t\t{extra},")
        add("\t\t\t);")
        add(f"\t\t\tpath = {quote(node.name)};")
        add('\t\t\tsourceTree = "<group>";')
        add("\t\t};")
        for child in node.children:
            if child.is_dir:
                emit_group(child)

    emit_group(app_tree, [f"{oid('variantgroup', 'LaunchScreen')} /* LaunchScreen.storyboard */"])
    emit_group(widget_tree)
    if not SKIP_WATCH:
        emit_group(watch_tree)
    emit_group(test_tree)

    add(f"\t\t{oid('group', 'Products')} /* Products */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    for target in targets:
        add(f"\t\t\t\t{target.product_uuid} /* {target.product_name} */,")
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")

    add(f"\t\t{oid('group', 'main')} = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{app_tree.uuid} /* {APP_DIR} */,")
    add(f"\t\t\t\t{widget_tree.uuid} /* {WIDGET_DIR} */,")
    if not SKIP_WATCH:
        add(f"\t\t\t\t{watch_tree.uuid} /* {WATCH_DIR} */,")
    add(f"\t\t\t\t{test_tree.uuid} /* {TEST_DIR} */,")
    add(f"\t\t\t\t{oid('group', 'Products')} /* Products */,")
    add("\t\t\t);")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")
    add("/* End PBXGroup section */")

    # ---- PBXNativeTarget
    add("\n/* Begin PBXNativeTarget section */")
    for target in targets:
        phases = [
            f"{oid('phase', 'sources', target.name)} /* Sources */",
            f"{oid('phase', 'frameworks', target.name)} /* Frameworks */",
            f"{oid('phase', 'resources', target.name)} /* Resources */",
        ]
        if target is app:
            phases.append(f"{oid('phase', 'embed-widget')} /* Embed Foundation Extensions */")
            if not SKIP_WATCH:
                phases.append(f"{oid('phase', 'embed-watch')} /* Embed Watch Content */")
        add(f"\t\t{target.uuid} /* {target.name} */ = {{")
        add("\t\t\tisa = PBXNativeTarget;")
        add(f"\t\t\tbuildConfigurationList = {oid('configlist', target.name)} "
            f'/* Build configuration list for PBXNativeTarget "{target.name}" */;')
        add("\t\t\tbuildPhases = (")
        for phase in phases:
            add(f"\t\t\t\t{phase},")
        add("\t\t\t);")
        add("\t\t\tbuildRules = (")
        add("\t\t\t);")
        add("\t\t\tdependencies = (")
        for dep in target.dependencies:
            add(f"\t\t\t\t{oid('dependency', dep.name)} /* PBXTargetDependency */,")
        add("\t\t\t);")
        add(f"\t\t\tname = {quote(target.name)};")
        add(f"\t\t\tproductName = {quote(target.name)};")
        add(f"\t\t\tproductReference = {target.product_uuid} /* {target.product_name} */;")
        add(f'\t\t\tproductType = "{target.product_type}";')
        add("\t\t};")
    add("/* End PBXNativeTarget section */")

    # ---- PBXProject
    add("\n/* Begin PBXProject section */")
    add(f"\t\t{oid('project')} /* Project object */ = {{")
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1610;")
    add("\t\t\t\tLastUpgradeCheck = 1610;")
    add("\t\t\t\tTargetAttributes = {")
    for target in targets:
        add(f"\t\t\t\t\t{target.uuid} = {{")
        add("\t\t\t\t\t\tCreatedOnToolsVersion = 16.1;")
        add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f"\t\t\tbuildConfigurationList = {oid('configlist', 'project')} "
        f'/* Build configuration list for PBXProject "{PROJECT_NAME}" */;')
    add('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    add("\t\t\tdevelopmentRegion = de;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\tde,")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f"\t\t\tmainGroup = {oid('group', 'main')};")
    add(f"\t\t\tproductRefGroup = {oid('group', 'Products')} /* Products */;")
    add('\t\t\tprojectDirPath = "";')
    add('\t\t\tprojectRoot = "";')
    add("\t\t\ttargets = (")
    for target in targets:
        add(f"\t\t\t\t{target.uuid} /* {target.name} */,")
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")

    # ---- PBXResourcesBuildPhase
    add("\n/* Begin PBXResourcesBuildPhase section */")
    for target in targets:
        add(f"\t\t{oid('phase', 'resources', target.name)} /* Resources */ = {{")
        add("\t\t\tisa = PBXResourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for rel in target.resources:
            add(f"\t\t\t\t{target.build_file(rel)} /* {Path(rel).name} */,")
        if target is app:
            add(f"\t\t\t\t{oid('buildfile', app.name, 'LaunchScreen')} /* LaunchScreen.storyboard */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")

    # ---- PBXSourcesBuildPhase
    add("\n/* Begin PBXSourcesBuildPhase section */")
    for target in targets:
        add(f"\t\t{oid('phase', 'sources', target.name)} /* Sources */ = {{")
        add("\t\t\tisa = PBXSourcesBuildPhase;")
        add("\t\t\tbuildActionMask = 2147483647;")
        add("\t\t\tfiles = (")
        for rel in target.sources:
            add(f"\t\t\t\t{target.build_file(rel)} /* {Path(rel).name} */,")
        add("\t\t\t);")
        add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")

    # ---- PBXTargetDependency
    add("\n/* Begin PBXTargetDependency section */")
    for _, dep in dep_pairs:
        add(f"\t\t{oid('dependency', dep.name)} /* PBXTargetDependency */ = {{")
        add("\t\t\tisa = PBXTargetDependency;")
        add(f"\t\t\ttarget = {dep.uuid} /* {dep.name} */;")
        add(f"\t\t\ttargetProxy = {oid('proxy', dep.name)} /* PBXContainerItemProxy */;")
        add("\t\t};")
    add("/* End PBXTargetDependency section */")

    # ---- PBXVariantGroup
    add("\n/* Begin PBXVariantGroup section */")
    add(f"\t\t{oid('variantgroup', 'LaunchScreen')} /* LaunchScreen.storyboard */ = {{")
    add("\t\t\tisa = PBXVariantGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{oid('file', f'{APP_DIR}/Base.lproj/LaunchScreen.storyboard')} /* Base */,")
    add("\t\t\t);")
    add("\t\t\tname = LaunchScreen.storyboard;")
    add('\t\t\tsourceTree = "<group>";')
    add("\t\t};")
    add("/* End PBXVariantGroup section */")

    # ---- XCBuildConfiguration
    add("\n/* Begin XCBuildConfiguration section */")

    def emit_config(owner: str, config: str, settings: dict):
        add(f"\t\t{oid('config', owner, config)} /* {config} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        add(render_settings(settings, "\t\t\t\t"))
        add("\t\t\t};")
        add(f"\t\t\tname = {config};")
        add("\t\t};")

    emit_config("project", "Debug", PROJECT_DEBUG)
    emit_config("project", "Release", PROJECT_RELEASE)
    all_settings = [(app, APP_SETTINGS), (widget, WIDGET_SETTINGS)]
    if not SKIP_WATCH:
        all_settings.append((watch, WATCH_SETTINGS))
    all_settings.append((tests, TEST_SETTINGS))
    for target, settings in all_settings:
        emit_config(target.name, "Debug", settings)
        emit_config(target.name, "Release", settings)
    add("/* End XCBuildConfiguration section */")

    # ---- XCConfigurationList
    add("\n/* Begin XCConfigurationList section */")

    def emit_config_list(owner: str, label: str):
        add(f"\t\t{oid('configlist', owner)} /* Build configuration list for {label} */ = {{")
        add("\t\t\tisa = XCConfigurationList;")
        add("\t\t\tbuildConfigurations = (")
        add(f"\t\t\t\t{oid('config', owner, 'Debug')} /* Debug */,")
        add(f"\t\t\t\t{oid('config', owner, 'Release')} /* Release */,")
        add("\t\t\t);")
        add("\t\t\tdefaultConfigurationIsVisible = 0;")
        add("\t\t\tdefaultConfigurationName = Release;")
        add("\t\t};")

    emit_config_list("project", f'PBXProject "{PROJECT_NAME}"')
    for target in targets:
        emit_config_list(target.name, f'PBXNativeTarget "{target.name}"')
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f"\trootObject = {oid('project')} /* Project object */;")
    add("}")
    return "\n".join(L) + "\n"


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1610" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{uuid}"
               BuildableName = "{product}"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{project}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>{testables}</Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{uuid}"
            BuildableName = "{product}"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{project}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{uuid}"
            BuildableName = "{product}"
            BlueprintName = "{name}"
            ReferencedContainer = "container:{project}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


TESTABLE = """
         <TestableReference skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{uuid}"
               BuildableName = "{product}"
               BlueprintName = "{name}"
               ReferencedContainer = "container:{project}.xcodeproj">
            </BuildableReference>
         </TestableReference>
      """


def write_schemes(targets, tests=None):
    """Ein geteiltes Schema je startbarem Ziel. Nur das App-Schema bekommt die
    Tests angehängt — `xcodebuild test -scheme Kraftwuerfel` findet sie damit
    ohne weiteres Zutun."""
    schemes_dir = XCODEPROJ / "xcshareddata" / "xcschemes"
    schemes_dir.mkdir(parents=True, exist_ok=True)

    testables = ""
    if tests is not None:
        testables = TESTABLE.format(
            uuid=tests.uuid,
            product=tests.product_name,
            name=tests.name,
            project=PROJECT_NAME,
        )

    for target in targets:
        (schemes_dir / f"{target.name}.xcscheme").write_text(
            SCHEME.format(
                uuid=target.uuid,
                product=target.product_name,
                name=target.name,
                project=PROJECT_NAME,
                testables=testables if target.product_type.endswith("application")
                          and target.name == PROJECT_NAME else "",
            ),
            encoding="utf-8",
        )


def main() -> int:
    pbxproj = generate()

    if XCODEPROJ.exists():
        shutil.rmtree(XCODEPROJ / "project.xcworkspace", ignore_errors=True)
    XCODEPROJ.mkdir(exist_ok=True)
    (XCODEPROJ / "project.pbxproj").write_text(pbxproj, encoding="utf-8")

    app_tree = build_tree(APP_DIR)
    widget_tree = build_tree(WIDGET_DIR)
    watch_tree = build_tree(WATCH_DIR)
    test_tree = build_tree(TEST_DIR)
    app, widget, watch, tests = collect(app_tree, widget_tree, watch_tree, test_tree)
    write_schemes([app] if SKIP_WATCH else [app, watch], tests)

    print(f"{XCODEPROJ.relative_to(ROOT)}/project.pbxproj geschrieben")
    listed = [app, widget] if SKIP_WATCH else [app, widget, watch]
    for target in listed + [tests]:
        print(f"  {target.name:22} {len(target.sources):3} Quellen, "
              f"{len(target.resources):2} Ressourcen")
    if SKIP_WATCH:
        print("  ACHTUNG: ohne watchOS-Ziel erzeugt (KRAFT_SKIP_WATCH=1) — nur zum Prüfen.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
