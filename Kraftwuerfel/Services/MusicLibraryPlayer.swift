import Foundation
import SwiftUI
import MediaPlayer

/*
  Musik für die Live-Session aus der Mediathek des Geräts.

  Im Web muss der Nutzer MP3-Dateien hochladen, weil ein Browser nicht an die
  Apple-Music-Bibliothek kommt. Nativ geht das direkt: MPMediaPickerController
  zeigt die lokale Mediathek inklusive der aus Apple Music geladenen Titel,
  und MPMusicPlayerController spielt sie ab — auch bei gesperrtem Bildschirm,
  weil iOS die Wiedergabe selbst auf dem Sperrbildschirm anzeigt.

  Deshalb greift hier bewusst NICHT das Datei-Modell des Webs: heruntergeladene
  Apple-Music-Titel sind DRM-geschützt und lassen sich nicht kopieren — nur
  über den System-Player abspielen.
*/
@MainActor
public final class MusicLibraryPlayer: NSObject, ObservableObject {
    public static let shared = MusicLibraryPlayer()

    @Published public private(set) var tracks: [MPMediaItem] = []
    @Published public private(set) var currentTitle: String = ""
    @Published public private(set) var currentArtist: String = ""
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isShuffleEnabled: Bool = false
    @Published public var authorizationDenied: Bool = false

    private static let storageKey = "kraftwuerfel:saved_playlist_ids"

    /// Der App-eigene Player: die Warteschlange gehört uns, die Systemmusik
    /// des Nutzers bleibt unangetastet.
    private let player = MPMusicPlayerController.applicationQueuePlayer

    private override init() {
        super.init()
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            self, selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange, object: player)
        NotificationCenter.default.addObserver(
            self, selector: #selector(nowPlayingChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange, object: player)

        restoreSavedPlaylist()
    }

    // MARK: - Zugriff

    public var isAuthorized: Bool {
        MPMediaLibrary.authorizationStatus() == .authorized
    }

    public func requestAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
        authorizationDenied = (status == .denied || status == .restricted)
        if status == .authorized {
            restoreSavedPlaylist()
        }
    }

    // MARK: - Persistenz

    private func savePlaylist() {
        let ids = tracks.map { "\($0.persistentID)" }
        UserDefaults.standard.set(ids, forKey: Self.storageKey)
    }

    public func restoreSavedPlaylist() {
        guard isAuthorized else { return }
        guard let savedIds = UserDefaults.standard.stringArray(forKey: Self.storageKey), !savedIds.isEmpty else { return }

        let query = MPMediaQuery.songs()
        guard let allItems = query.items, !allItems.isEmpty else { return }

        var itemMap: [String: MPMediaItem] = [:]
        for item in allItems {
            itemMap["\(item.persistentID)"] = item
        }

        let restored = savedIds.compactMap { itemMap[$0] }
        if !restored.isEmpty {
            self.tracks = restored
        }
    }

    // MARK: - Warteschlange

    // MARK: - Playlists der Mediathek

    /*
      Die eigenen Playlists des Nutzers.

      Vorher gab es nur eine Liste: alle einzeln ausgewählten Titel
      hintereinander. Wer für sein Training schon eine Playlist angelegt hat —
      und das haben die meisten —, musste sie hier Titel für Titel
      nachbauen. Gelesen wird direkt aus der Mediathek; angelegt oder
      geändert wird dort nichts.
    */
    public struct LibraryPlaylist: Identifiable, Equatable {
        public let id: UInt64
        public let name: String
        public let trackCount: Int
        public let items: [MPMediaItem]

        public static func == (a: LibraryPlaylist, b: LibraryPlaylist) -> Bool { a.id == b.id }
    }

    @Published public private(set) var playlists: [LibraryPlaylist] = []
    /// Welche Playlist gerade geladen ist — `nil` bei einer selbst
    /// zusammengestellten Auswahl.
    @Published public private(set) var loadedPlaylistID: UInt64?

    public func loadPlaylists() {
        guard isAuthorized else { return }

        let query = MPMediaQuery.playlists()
        let collections = query.collections ?? []

        playlists = collections.compactMap { collection in
            guard let playlist = collection as? MPMediaPlaylist else { return nil }
            /*
              Hier stand ein Filter auf `!isCloudItem || assetURL != nil` — also
              „nur was wirklich auf dem Gerät liegt". Für jeden mit einem
              Apple-Music-Abo ist das faktisch die ganze Mediathek: Cloud-Titel
              haben erst nach dem Herunterladen eine `assetURL`. Damit fielen
              sämtliche Titel weg, die Playlist galt als leer und flog raus —
              und weil danach keine einzige Playlist übrig blieb, zeigte die
              Ansicht überhaupt keinen Playlist-Bereich an.

              MPMusicPlayerController spielt Cloud-Titel mit bestehendem Abo
              ab. Sie auszublenden nimmt dem Nutzer also genau das, was er
              hören will. Wirklich leere Playlists fliegen weiter raus.
            */
            let items = playlist.items
            guard !items.isEmpty else { return nil }
            return LibraryPlaylist(
                id: playlist.persistentID,
                name: playlist.name ?? (I18n.shared.lang == "en" ? "Playlist" : "Wiedergabeliste"),
                trackCount: items.count,
                items: items
            )
        }
    }

    /// Eine ganze Playlist übernehmen — ersetzt die aktuelle Auswahl.
    public func loadPlaylist(_ playlist: LibraryPlaylist) {
        setQueue(playlist.items)
        loadedPlaylistID = playlist.id
    }

    public func setQueue(_ items: [MPMediaItem], startAt index: Int = 0) {
        // Die Sitzung steht, bevor die erste Note läuft — sonst kann der
        // erste Countdown-Ping sie wieder abwürgen.
        AudioSessionManager.configureForWorkout()
        guard !items.isEmpty else { return }
        tracks = items
        savePlaylist()

        let collection = MPMediaItemCollection(items: items)
        player.setQueue(with: collection)
        player.shuffleMode = .off
        player.repeatMode = .all
        player.nowPlayingItem = items[min(index, items.count - 1)]
        player.play()
        refreshNowPlaying()
    }

    public func addTracks(_ items: [MPMediaItem]) {
        // Wer eigene Titel dazulegt, hört nicht mehr die Playlist von vorhin.
        loadedPlaylistID = nil
        guard !items.isEmpty else { return }
        var updated = tracks
        for item in items {
            if !updated.contains(where: { $0.persistentID == item.persistentID }) {
                updated.append(item)
            }
        }
        tracks = updated
        savePlaylist()

        if !isPlaying {
            let collection = MPMediaItemCollection(items: updated)
            player.setQueue(with: collection)
            player.shuffleMode = isShuffleEnabled ? .songs : .off
            player.repeatMode = .all
            if let first = updated.first {
                player.nowPlayingItem = first
            }
            refreshNowPlaying()
        }
    }

    public func play(_ item: MPMediaItem) {
        guard let index = tracks.firstIndex(where: { $0.persistentID == item.persistentID }) else { return }
        setQueue(tracks, startAt: index)
    }

    public func remove(_ item: MPMediaItem) {
        tracks.removeAll { $0.persistentID == item.persistentID }
        savePlaylist()
        if tracks.isEmpty {
            clearPlaylist()
        } else if player.nowPlayingItem?.persistentID == item.persistentID {
            setQueue(tracks)
        }
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        tracks.move(fromOffsets: source, toOffset: destination)
        savePlaylist()
    }

    public func clearPlaylist() {
        loadedPlaylistID = nil
        player.stop()
        tracks = []
        currentTitle = ""
        currentArtist = ""
        isPlaying = false
        isShuffleEnabled = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    // MARK: - Steuerung

    public func toggle() {
        if player.playbackState == .playing { player.pause() } else { player.play() }
        refreshNowPlaying()
    }

    public func next() { player.skipToNextItem(); refreshNowPlaying() }
    public func previous() {
        // Wie überall: erst an den Anfang, beim zweiten Druck zurück.
        if player.currentPlaybackTime > 3 {
            player.skipToBeginning()
        } else {
            player.skipToPreviousItem()
        }
        refreshNowPlaying()
    }

    public func toggleShuffle() {
        if isShuffleEnabled {
            player.shuffleMode = .off
            isShuffleEnabled = false
        } else {
            player.shuffleMode = .songs
            isShuffleEnabled = true
        }
    }

    public func shuffleAll() {
        guard !tracks.isEmpty else { return }
        var shuffled = tracks
        shuffled.shuffle()
        setQueue(shuffled, startAt: 0)
        player.shuffleMode = .songs
        isShuffleEnabled = true
    }

    public func stop() {
        player.stop()
        isPlaying = false
        refreshNowPlaying()
    }

    // MARK: - Zustand

    @objc private func playbackStateChanged() { refreshNowPlaying() }
    @objc private func nowPlayingChanged() { refreshNowPlaying() }

    private func refreshNowPlaying() {
        isPlaying = player.playbackState == .playing
        currentTitle = player.nowPlayingItem?.title ?? ""
        currentArtist = player.nowPlayingItem?.artist ?? ""
    }

    /// Gesamtdauer der Playlist — steht als Fußnote unter der Liste.
    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.playbackDuration }
    }
}

/*
  Der System-Auswahldialog. Er zeigt genau das, was auf dem Gerät liegt —
  gekaufte Titel und aus Apple Music heruntergeladene gleichermaßen.
*/
public struct MediaPicker: UIViewControllerRepresentable {
    public var onPicked: ([MPMediaItem]) -> Void

    public init(onPicked: @escaping ([MPMediaItem]) -> Void) {
        self.onPicked = onPicked
    }

    public func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = true
        /*
          Cloud-Titel mitzeigen. Vorher stand hier `false` mit der Begründung
          „nur wirklich vorhandene Titel" — für Apple-Music-Abonnenten ist das
          aber nahezu die gesamte Mediathek, und die Auswahl blieb leer.
        */
        picker.showsCloudItems = true
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ controller: MPMediaPickerController, context: Context) {}

    public func makeCoordinator() -> Coordinator { Coordinator(self) }

    public final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        private let parent: MediaPicker
        init(_ parent: MediaPicker) { self.parent = parent }

        public func mediaPicker(_ mediaPicker: MPMediaPickerController,
                                didPickMediaItems collection: MPMediaItemCollection) {
            parent.onPicked(collection.items)
            mediaPicker.dismiss(animated: true)
        }

        public func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            mediaPicker.dismiss(animated: true)
        }
    }
}

/*
  Spotify für die Live-Session — ein Knopf, kein Formular.

  Vorher musste der Nutzer einen Playlist-Link von Hand einfügen. Das war der
  Preis dafür, dass die App die Playlist selbst starten wollte: Ohne SDK kennt
  sie keine einzige Playlist des Nutzers, also musste er ihr eine nennen.

  Der Umweg lohnt sich nicht. Ein blankes `spotify:` öffnet die Spotify-App
  dort, wo der Nutzer ohnehin hinwill — seine eigenen Playlists, mit Suche und
  Empfehlungen. Er tippt eine an, sie läuft, er wischt zurück ins Training.
  Genauso viele Schritte wie vorher, aber ohne einmaliges Link-Kopieren.

  Was damit bewusst NICHT geht: Die App erfährt nie, was gerade läuft, und
  kann Wiedergabe weder starten noch steuern. Dafür bräuchte es das App Remote
  SDK samt Spotify-Entwicklerkonto und Client-ID.
*/
@MainActor
public final class SpotifyConnectService: ObservableObject {
    public static let shared = SpotifyConnectService()

    private init() {}

    /// Ohne `LSApplicationQueriesSchemes`-Eintrag in der Info.plist antwortet
    /// iOS hier immer mit `false`, egal ob Spotify installiert ist.
    public var isSpotifyInstalled: Bool {
        guard let scheme = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(scheme)
    }

    /// Öffnet Spotify — die Auswahl trifft der Nutzer dort.
    public func openSpotify() {
        open(app: "spotify:", web: "https://open.spotify.com")
    }

    /// Direkt in die Suche nach Workout-Playlists. Spart das Tippen, wenn der
    /// Nutzer noch keine eigene Trainings-Playlist hat.
    public func openWorkoutPlaylists() {
        open(app: "spotify:search:workout", web: "https://open.spotify.com/search/workout/playlists")
    }

    /// Ist Spotify nicht installiert, übernimmt der Browser — dort kann der
    /// Nutzer die App laden oder im Web-Player hören. Ein toter Knopf wäre die
    /// schlechtere Antwort.
    private func open(app: String, web: String) {
        if isSpotifyInstalled, let appURL = URL(string: app) {
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
        } else if let webURL = URL(string: web) {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }
    }
}
