import SwiftUI

/*
  Das Übungsbild groß.

  Aus der Zeile heraus ist ein Foto 32 bis 40 Punkte breit — genug, um die
  Übung wiederzuerkennen, zu wenig, um die Ausführung daran abzulesen. Ein
  Tippen darauf zeigt es deshalb bildschirmfüllend.

  Geschlossen wird an drei Stellen, weil es hier nichts zu bestätigen gibt und
  jeder woanders sucht: das Kreuz oben rechts, ein Tippen irgendwo aufs Bild
  und ein Wischen nach unten. Ohne die letzte Geste wirkt eine Vollbildansicht
  auf iOS festgefahren — sie ist die, die man ohne Nachdenken versucht.
*/
public struct ExerciseImageViewer: View {
    @ObservedObject private var i18n = I18n.shared
    @Environment(\.dismiss) private var dismiss

    private let exercise: Exercise

    /// Wie weit die Ansicht dem Wischen schon gefolgt ist.
    @State private var dragOffset: CGFloat = 0

    public init(exercise: Exercise) {
        self.exercise = exercise
    }

    public var body: some View {
        ZStack {
            /*
              Schwarz, nicht Theme.bg: Ein Foto steht auf reinem Schwarz ohne
              den leichten Blaustich, den der App-Grund sonst danebenlegt.
            */
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(exercise.imageAssetKey)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                caption
            }
            .offset(y: dragOffset)
            // Beim Wegziehen blendet der Inhalt aus, statt hart zu verschwinden.
            .opacity(1 - min(1.0, abs(dragOffset) / 400.0))
        }
        .overlay(alignment: .topTrailing) { closeButton }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Nur nach unten mitgehen; nach oben gibt es nichts zu sehen.
                    dragOffset = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }

    private var caption: some View {
        VStack(spacing: 4) {
            Text(i18n.exerciseName(exercise))
                .font(KraftFont.bebas(22)).tracking(1)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text(i18n.category(exercise.category))
                    .font(KraftFont.mono(11, .bold)).tracking(0.5)
                    .foregroundColor(Theme.accent)
                Text("·")
                    .foregroundColor(Theme.muted)
                Text(i18n.equipment(exercise.equipment))
                    .font(KraftFont.inter(12))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                /*
                  Der Kreis liegt auf halbdurchsichtigem Grau, nicht auf der
                  Flächenfarbe: Das Kreuz steht über dem Foto und dessen
                  Helligkeit ist unbekannt — auf einem hellen Bild wäre ein
                  dunkles Kreuz ohne Scheibe darunter nicht zu finden.
                */
                .background(Circle().fill(Color.white.opacity(0.18)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.trailing, 16)
        .accessibilityLabel(Text(i18n.t("saved.close")))
    }
}
