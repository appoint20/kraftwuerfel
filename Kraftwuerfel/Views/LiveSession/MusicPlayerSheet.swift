import SwiftUI
import MediaPlayer

/*
  Portierung von src/components/GymMusicPlayer.jsx (.music-sheet).

  Der Streaming-Reiter des Webs fehlt hier bewusst: er existiert nur, weil ein
  Browser nicht an die Apple-Music-Mediathek kommt. Nativ ist genau das der
  Normalfall, also gibt es nur die Mediathek.
*/
public struct MusicPlayerSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var music = MusicLibraryPlayer.shared

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
                    if music.tracks.isEmpty { emptyState } else { trackList }
                    addButton
                    if music.authorizationDenied { deniedHint }
                }
                .padding(16)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
        }
        .task { await music.requestAuthorization() }
        .sheet(isPresented: $showPicker) {
            MediaPicker { items in
                guard !items.isEmpty else { return }
                music.setQueue(items)
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

            HStack(spacing: 14) {
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

    private func controlButton(_ symbol: String, size: CGFloat, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(Theme.text)
                .padding(6)
        }
        .buttonStyle(.plain)
    }

    private var trackList: some View {
        VStack(spacing: 6) {
            ForEach(music.tracks, id: \.persistentID) { item in
                let isCurrent = item.title == music.currentTitle && !music.currentTitle.isEmpty
                HStack(spacing: 10) {
                    Button(action: { music.play(item) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.accent)
                            .frame(width: 30, height: 30)
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

                    Button(action: { music.remove(item) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.muted)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
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

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }
}
