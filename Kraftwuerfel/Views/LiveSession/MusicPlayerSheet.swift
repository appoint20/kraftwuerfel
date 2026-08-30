import SwiftUI
import MediaPlayer

/*
  Portierung von src/components/GymMusicPlayer.jsx (.music-sheet).

  Der generische Streaming-Reiter des Webs fehlt hier bewusst: er existiert
  nur, weil ein Browser nicht an die Apple-Music-Mediathek kommt. Nativ ist
  genau das der Normalfall, also gibt es die Mediathek direkt oben.

  Spotify steht separat darunter — nicht als Ersatz für die Mediathek, sondern
  als eigene Anbindung fürs Trainings-Playlist-Starten. Siehe
  SpotifyConnectService für das Warum ohne SDK.
*/
public struct MusicPlayerSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var music = MusicLibraryPlayer.shared
    @ObservedObject private var spotify = SpotifyConnectService.shared

    @State private var showPicker = false
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if !music.currentTitle.isEmpty { nowPlaying }
                    playlistSection
                    if music.tracks.isEmpty { emptyState } else { trackList }
                    addButton
                    if music.authorizationDenied { deniedHint }

                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 2)

                    spotifySection
                }
                .padding(16)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }

            AdOverlayModal()
        }
        .task {
            await music.requestAuthorization()
            music.loadPlaylists()
        }
        .sheet(isPresented: $showPicker) {
            MediaPicker { items in
                guard !items.isEmpty else { return }
                music.addTracks(items)
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "music.note").font(.system(size: 15, weight: .bold))
                Text(i18n.t("music.title"))
                    .font(KraftFont.bebas(19)).tracking(1)
            }
            .foregroundColor(Theme.accent)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.muted)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
    }

    /// .music-now — läuft gerade, mit Zurück/Play/Weiter.
    private var nowPlaying: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(music.currentTitle)
                    .font(KraftFont.inter(14, .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                if !music.currentArtist.isEmpty {
                    Text(music.currentArtist)
                        .font(KraftFont.inter(11))
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 18) {
                controlButton("shuffle", size: 15, isActive: music.isShuffleEnabled) {
                    music.toggleShuffle()
                }

                controlButton("backward.fill", size: 16) { music.previous() }

                Button(action: { music.toggle() }) {
                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.bg)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.accent))
                }
                .buttonStyle(.plain)

                controlButton("forward.fill", size: 16) { music.next() }
            }

            Text(i18n.t("music.lockScreenHint"))
                .font(KraftFont.inter(10.5))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.accent, lineWidth: 1))
    }

    private func controlButton(_ symbol: String, size: CGFloat, isActive: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(isActive ? Theme.accent : Theme.text)
                .padding(6)
                .background(isActive ? Circle().fill(Theme.accentDim) : Circle().fill(Color.clear))
        }
        .buttonStyle(.plain)
    }

    /*
      Die Playlists aus der Mediathek.

      Bisher zeigte dieses Blatt genau eine flache Liste: alle einzeln
      hinzugefügten Titel untereinander. Wer für sein Training längst eine
      Playlist hat, musste sie hier Titel für Titel nachbauen — bei dreißig
      Songs dreißig Mal auswählen.

      Eine Zeile je Playlist, ein Tipp lädt sie. Die eigene Auswahl bleibt
      daneben bestehen, für alle, die genau das wollten.
    */
    @ViewBuilder
    private var playlistSection: some View {
        if !music.playlists.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(i18n.lang == "en" ? "YOUR PLAYLISTS" : "DEINE WIEDERGABELISTEN")
                        .font(KraftFont.bebas(13)).tracking(1.2)
                        .foregroundColor(Theme.accent)
                    Spacer()
                    Text("\(music.playlists.count)")
                        .font(KraftFont.mono(10.5, .bold))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 4)

                /*
                  Waagerecht, damit acht Playlists nicht die Titelliste
                  darunter aus dem Bild schieben.
                */
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(music.playlists) { playlist in
                            playlistCard(playlist)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func playlistCard(_ playlist: MusicLibraryPlayer.LibraryPlaylist) -> some View {
        let isLoaded = music.loadedPlaylistID == playlist.id
        return Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            music.loadPlaylist(playlist)
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: isLoaded ? "checkmark.circle.fill" : "music.note.list")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isLoaded ? Theme.bg : Theme.accent)

                Text(playlist.name)
                    .font(KraftFont.inter(13, .semibold))
                    .foregroundColor(isLoaded ? Theme.bg : Theme.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Text("\(playlist.trackCount) \(i18n.lang == "en" ? "tracks" : "Titel")")
                    .font(KraftFont.mono(10, .bold))
                    .foregroundColor(isLoaded ? Theme.bg.opacity(0.75) : Theme.muted)
            }
            .padding(10)
            .frame(width: 132, height: 96, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12).fill(isLoaded ? Theme.accent : Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isLoaded ? Theme.accent : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(playlist.name), \(playlist.trackCount)")
    }

    private var trackList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(music.tracks.count) \(i18n.lang == "en" ? "Tracks" : "Titel") · \(durationText(music.totalDuration))")
                    .font(KraftFont.mono(11, .medium))
                    .foregroundColor(Theme.muted)

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    music.shuffleAll()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle").font(.system(size: 11, weight: .bold))
                        Text(i18n.lang == "en" ? "Shuffle" : "Mischen")
                            .font(KraftFont.inter(11, .bold))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentDim)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    music.clearPlaylist()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Theme.surface2)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            ForEach(Array(music.tracks.enumerated()), id: \.element.persistentID) { index, item in
                let isCurrent = item.title == music.currentTitle && !music.currentTitle.isEmpty
                HStack(spacing: 8) {
                    Button(action: { music.play(item) }) {
                        Image(systemName: isCurrent && music.isPlaying ? "speaker.wave.2.fill" : "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.accent)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Theme.accentDim))
                            .overlay(Circle().stroke(Theme.accent, lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title ?? "—")
                            .font(KraftFont.inter(13, .semibold))
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Text("\(item.artist ?? "") · \(durationText(item.playbackDuration))"
                                .trimmingCharacters(in: CharacterSet(charactersIn: " ·")))
                            .font(KraftFont.mono(10, .medium))
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    // Track reordering up / down
                    if music.tracks.count > 1 {
                        VStack(spacing: 2) {
                            if index > 0 {
                                Button(action: {
                                    music.move(fromOffsets: IndexSet(integer: index), toOffset: index - 1)
                                }) {
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Theme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                            if index < music.tracks.count - 1 {
                                Button(action: {
                                    music.move(fromOffsets: IndexSet(integer: index), toOffset: index + 2)
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(Theme.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button(action: { music.remove(item) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isCurrent ? Theme.accent : Theme.border, lineWidth: 1)
                )
            }

            Text(i18n.t("music.usage", [
                "n": "\(music.tracks.count)",
                "size": durationText(music.totalDuration),
            ]))
            .font(KraftFont.inter(11))
            .foregroundColor(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "music.note.list")
                .font(.system(size: 24))
                .foregroundColor(Theme.muted)
            Text(i18n.t("music.emptyTitle"))
                .font(KraftFont.inter(13, .semibold))
                .foregroundColor(Theme.text)
            Text(i18n.t("music.emptyTextNative"))
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundColor(Theme.border)
        )
    }

    private var addButton: some View {
        KraftPrimaryButton(i18n.t("music.add"), systemImage: "plus", compact: true) {
            showPicker = true
        }
    }

    private var deniedHint: some View {
        Text(i18n.t("music.denied"))
            .font(KraftFont.inter(12, .semibold))
            .foregroundColor(Theme.red)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.red.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.red, lineWidth: 1))
    }

    // MARK: - Spotify (.music-spotify)

    /*
      Ein Knopf, kein Eingabefeld. Spotify geht auf, der Nutzer tippt seine
      Playlist an, sie läuft — siehe SpotifyConnectService, warum die App die
      Auswahl nicht selbst treffen kann.
    */
    private var spotifySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.green)
                Text(i18n.t("music.spotifyTitle"))
                    .font(KraftFont.bebas(15)).tracking(1)
                    .foregroundColor(Theme.text)
            }

            Text(i18n.t("music.spotifyHint"))
                .font(KraftFont.inter(11.5))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                spotify.openSpotify()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(i18n.t("music.spotifyOpen"))
                        .font(KraftFont.bebas(15)).tracking(1.2)
                        .textCase(.uppercase)
                }
                .foregroundColor(Theme.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 11).fill(Theme.green))
            }
            .buttonStyle(.plain)

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                spotify.openWorkoutPlaylists()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                    Text(i18n.t("music.spotifyBrowseWorkout"))
                        .font(KraftFont.inter(12.5, .semibold))
                }
                .foregroundColor(Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Ohne installierte App landet der Knopf im Browser — das sollte
            // dranstehen, bevor der Nutzer draufdrückt.
            if !spotify.isSpotifyInstalled {
                Text(i18n.t("music.spotifyNotInstalled"))
                    .font(KraftFont.inter(10.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface2))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }
}
