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
    @Published public var authorizationDenied: Bool = false

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
    }

    // MARK: - Warteschlange

    public func setQueue(_ items: [MPMediaItem], startAt index: Int = 0) {
        guard !items.isEmpty else { return }
        tracks = items

        let collection = MPMediaItemCollection(items: items)
        player.setQueue(with: collection)
        player.shuffleMode = .off
        player.repeatMode = .all
        player.nowPlayingItem = items[min(index, items.count - 1)]
        player.play()
        refreshNowPlaying()
    }

    public func play(_ item: MPMediaItem) {
        guard let index = tracks.firstIndex(of: item) else { return }
        setQueue(tracks, startAt: index)
    }

    public func remove(_ item: MPMediaItem) {
        tracks.removeAll { $0 == item }
        if tracks.isEmpty {
            stop()
        } else if player.nowPlayingItem == item {
            setQueue(tracks)
        }
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

    public func stop() {
        player.stop()
        tracks = []
        currentTitle = ""
        currentArtist = ""
        isPlaying = false
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
        picker.showsCloudItems = false   // nur wirklich vorhandene Titel
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
