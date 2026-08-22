import { Capacitor } from "@capacitor/core";

/*
  Alles, was es nur in der nativen App gibt, an einer Stelle.

  Jede Funktion prüft selbst, ob sie überhaupt laufen kann, und tut sonst
  nichts. So bleibt der Rest der App frei von Plattform-Abfragen und der
  Web-Build verhält sich unverändert — im Browser sind das alles No-ops.

  Die Plugins werden erst bei Bedarf geladen (dynamic import). Im Web landen
  sie dadurch nicht im Startbundle.
*/

export const isNative = Capacitor.isNativePlatform();
export const platform = Capacitor.getPlatform(); // "ios" | "android" | "web"

/* Rückmeldung am Handgelenk statt auf dem Bildschirm — beim Training schaut
   man nicht hin. */
export async function haptic(style = "medium") {
  if (!isNative) return;
  try {
    const { Haptics, ImpactStyle } = await import("@capacitor/haptics");
    const map = { light: ImpactStyle.Light, medium: ImpactStyle.Medium, heavy: ImpactStyle.Heavy };
    await Haptics.impact({ style: map[style] || ImpactStyle.Medium });
  } catch {
    // Gerät ohne Taptic Engine
  }
}

export async function hapticSuccess() {
  if (!isNative) return;
  try {
    const { Haptics, NotificationType } = await import("@capacitor/haptics");
    await Haptics.notification({ type: NotificationType.Success });
  } catch {
    // ignorieren
  }
}

/* Der Start-Splash von Capacitor bleibt stehen, bis die App wirklich da ist. */
export async function hideNativeSplash() {
  if (!isNative) return;
  try {
    const { SplashScreen } = await import("@capacitor/splash-screen");
    await SplashScreen.hide({ fadeOutDuration: 250 });
  } catch {
    // ignorieren
  }
}

/*
  Statusleiste: nativ gesetzt, nicht über ein Plugin — Info.plist
  (UIStatusBarStyle) und styles.xml. Die App ist durchgehend dunkel und muss
  zur Laufzeit nie umschalten, also braucht es dafür keine Abhängigkeit.
*/
export async function setupStatusBar() {
  // absichtlich leer — die Konfiguration liegt in den nativen Projekten
}

/*
  Pausenwecker.

  Im Browser piept es nur, solange die Seite im Vordergrund ist — genau dann
  nicht, wenn man das Handy weglegt. Nativ geht eine echte Benachrichtigung
  raus, die auch auf der Uhr ankommt.
*/
const REST_NOTIFICATION_ID = 4711;

export async function scheduleRestAlarm(seconds, body) {
  if (!isNative || !(seconds >= 1)) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    const permission = await LocalNotifications.checkPermissions();
    if (permission.display !== "granted") {
      const asked = await LocalNotifications.requestPermissions();
      if (asked.display !== "granted") return;
    }
    await LocalNotifications.cancel({ notifications: [{ id: REST_NOTIFICATION_ID }] });
    await LocalNotifications.schedule({
      notifications: [
        {
          id: REST_NOTIFICATION_ID,
          title: "Kraftwürfel",
          body,
          schedule: { at: new Date(Date.now() + seconds * 1000) },
          sound: "default",
        },
      ],
    });
  } catch {
    // ignorieren
  }
}

export async function cancelRestAlarm() {
  if (!isNative) return;
  try {
    const { LocalNotifications } = await import("@capacitor/local-notifications");
    await LocalNotifications.cancel({ notifications: [{ id: REST_NOTIFICATION_ID }] });
  } catch {
    // ignorieren
  }
}

/* Android-Zurücktaste: erst die App schließen, wenn nichts mehr offen ist. */
export async function onBackButton(handler) {
  if (!isNative || platform !== "android") return () => {};
  try {
    const { App } = await import("@capacitor/app");
    const listener = await App.addListener("backButton", handler);
    return () => listener.remove();
  } catch {
    return () => {};
  }
}
