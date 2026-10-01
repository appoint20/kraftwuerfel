import SwiftUI

/*
  Bluetooth-Pulssensor koppeln — aus den Einstellungen und aus der
  Live-Session erreichbar.

  Die Liste sagt ausdrücklich, was geht und was nicht. Wer einen Oura-Ring
  trägt, soll hier lesen, dass er live nichts liefert, statt vergeblich zu
  suchen.

  Gesucht wird nur, solange das Blatt offen ist. Beim Schließen bleibt die
  Verbindung nur bestehen, wenn gerade eine Sitzung läuft — sonst kostet sie
  bloß Akku am Gurt. Der Sensor bleibt gemerkt und verbindet sich zur
  nächsten Sitzung selbst.
*/
public struct HeartRateSensorSheet: View {
    @ObservedObject private var i18n = I18n.shared
    @ObservedObject private var sensor = HeartRateSensorManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text(i18n.t("sensor.intro"))
                        .font(KraftFont.inter(13))
                        .foregroundColor(Theme.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)

                    statusBanner

                    if sensor.status == .connected || sensor.status == .connecting {
                        connectedCard
                    } else if let name = sensor.rememberedSensorName {
                        rememberedCard(name)
                    }

                    if showsSearch { searchSection }

                    compatibility
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(i18n.t("sensor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(i18n.lang == "en" ? "Done" : "Fertig") { dismiss() }
                        .font(KraftFont.inter(14, .bold))
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { sensor.startScan() }
        .onDisappear {
            sensor.stopScan()
            sensor.disconnectIfIdle()
        }
    }

    private var showsSearch: Bool {
        switch sensor.status {
        case .idle, .scanning: return true
        default: return false
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBanner: some View {
        switch sensor.status {
        case .bluetoothOff:
            banner(icon: "antenna.radiowaves.left.and.right.slash", text: i18n.t("sensor.bluetoothOff"))
        case .unauthorized:
            VStack(alignment: .leading, spacing: 10) {
                banner(icon: "lock.fill", text: i18n.t("sensor.unauthorized"))
                KraftPrimaryButton(i18n.t("sensor.openSettings"), systemImage: "gear", compact: true) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .unsupported:
            banner(icon: "exclamationmark.triangle.fill", text: i18n.t("sensor.unsupported"))
        default:
            EmptyView()
        }
    }

    private func banner(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.orange)
            Text(text)
                .font(KraftFont.inter(12))
                .foregroundColor(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Verbundener Sensor

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sensor.status == .connected ? i18n.t("sensor.connected") : i18n.t("sensor.connecting"))
                        .font(KraftFont.inter(10, .bold))
                        .textCase(.uppercase)
                        .foregroundColor(sensor.status == .connected ? Theme.accent : Theme.muted)
                    Text(sensor.sensorName ?? "")
                        .font(KraftFont.bebas(20)).tracking(1)
                        .foregroundColor(Theme.text)
                }
                Spacer(minLength: 0)
                liveReading
            }

            HStack(spacing: 10) {
                smallButton(i18n.t("sensor.disconnect")) { sensor.disconnect(forget: false) }
                smallButton(i18n.t("sensor.forget"), destructive: true) { sensor.disconnect(forget: true) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    @ViewBuilder
    private var liveReading: some View {
        if let bpm = sensor.freshHeartRate {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.pink)
                Text("\(bpm)").font(KraftFont.mono(30, .bold)).foregroundColor(Theme.text)
                Text("BPM").font(KraftFont.inter(10, .bold)).foregroundColor(Theme.muted)
            }
        } else if sensor.status == .connected {
            Text(sensor.hasSkinContact ? i18n.t("sensor.waiting") : i18n.t("sensor.noContact"))
                .font(KraftFont.inter(11, .semibold))
                .foregroundColor(sensor.hasSkinContact ? Theme.muted : Theme.orange)
                .multilineTextAlignment(.trailing)
        } else {
            ProgressView().tint(Theme.muted)
        }
    }

    private func rememberedCard(_ name: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("sensor.remembered", ["name": name]))
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.text.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                smallButton(i18n.t("sensor.forget"), destructive: true) { sensor.disconnect(forget: true) }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Suche

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(i18n.t("sensor.found").uppercased())

            if sensor.discovered.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    ProgressView().tint(Theme.muted)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t("sensor.searching"))
                            .font(KraftFont.inter(13, .semibold))
                            .foregroundColor(Theme.text)
                        Text(i18n.t("sensor.searchHint"))
                            .font(KraftFont.inter(11.5))
                            .foregroundColor(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            } else {
                ForEach(sensor.discovered.sorted { $0.rssi > $1.rssi }) { found in
                    discoveredRow(found)
                }
            }
        }
    }

    private func discoveredRow(_ found: HeartRateSensorManager.DiscoveredSensor) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            sensor.connect(found.id)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.pink)
                Text(found.name)
                    .font(KraftFont.inter(14, .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                signalBars(found.rssi)
                Text(i18n.t("sensor.connect"))
                    .font(KraftFont.inter(12, .bold))
                    .foregroundColor(Theme.accent)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Drei Balken für die Signalstärke — hilft, den eigenen Gurt von dem
    /// am Nachbargerät zu unterscheiden.
    private func signalBars(_ rssi: Int) -> some View {
        let level = rssi > -60 ? 3 : rssi > -75 ? 2 : 1
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= level ? Theme.text : Theme.border)
                    .frame(width: 3, height: CGFloat(4 + bar * 3))
            }
        }
    }

    // MARK: - Was geht, was nicht

    private var compatibility: some View {
        VStack(alignment: .leading, spacing: 12) {
            infoBlock(icon: "checkmark.circle.fill", tint: Theme.accent,
                      title: i18n.t("sensor.worksWith"), body: i18n.t("sensor.worksWithBody"))
            infoBlock(icon: "xmark.circle.fill", tint: Theme.muted,
                      title: i18n.t("sensor.notSupported"), body: i18n.t("sensor.notSupportedBody"))
        }
    }

    private func infoBlock(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(KraftFont.bebas(14)).tracking(1)
                    .foregroundColor(Theme.text)
                Text(body)
                    .font(KraftFont.inter(11.5))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func smallButton(_ title: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(KraftFont.inter(12, .bold))
                .foregroundColor(destructive ? Color(hex: "FC8181") : Theme.text)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface2))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
