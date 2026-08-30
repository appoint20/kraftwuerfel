import AVFoundation
import AudioToolbox
import Foundation
import UIKit
import UserNotifications

/*
  NotificationManager — Verwaltet lokale Push-Benachrichtigungen & Trainings-Audio.

  Features:
  1. Trainingstag-Erinnerungen: Wöchentlich wiederkehrende Benachrichtigungen
     an den gewählten Trainingstagen (z. B. 08:30 Uhr morgens).
  2. Satzpause-Beendet-Benachrichtigung: Benachrichtigt den Nutzer im Hintergrund
     oder auf dem Sperrbildschirm, wenn die Satzpause (Rest Timer) abgelaufen ist.
  3. Akustische Countdown-Signale (5..1 Ding-Ding) & energetische "LOS!" Sprach-/Audioausgabe.
*/
public final class NotificationManager: ObservableObject {
    public static let shared = NotificationManager()

    @Published public private(set) var isAuthorized: Bool = false

    private static let restNotificationId = "kraftwuerfel.live.restTimer"
    static let workoutReminderPrefix = "kraftwuerfel.workout.reminder."
    private let speechSynthesizer = AVSpeechSynthesizer()

    private init() {
        checkAuthorization()
    }

    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
        }
    }

    public func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Trainingstag-Erinnerungen

    /*
      Erinnerung an den Trainingstagen, morgens um neun — aber nur, wenn an
      dem Tag noch nicht trainiert wurde.

      Vorher stand hier ein wöchentlich wiederkehrender Auslöser je Wochentag
      (`repeats: true`). Der feuert unabänderlich: Wer montags früh im Studio
      war, bekam am nächsten Montag dieselbe Erinnerung — und eine Erinnerung
      an etwas, das man längst getan hat, ist genau die Sorte Meldung, nach
      der Leute Benachrichtigungen ganz abschalten. Ein einzelner
      wiederkehrender Auslöser lässt sich auch nicht für eine einzelne Woche
      abbestellen: Ihn zu löschen löscht alle künftigen mit.

      Deshalb einzelne, datierte Erinnerungen für die nächsten Wochen. Jede
      trägt ihr Datum im Namen, also lässt sich genau eine davon zurückziehen,
      sobald das Training an diesem Tag im Archiv steht. iOS hält bis zu 64
      offene Meldungen vor; vier Wochen mal höchstens sieben Tage bleiben
      darunter.
    */
    public func scheduleWorkoutDayReminders(
        days: [String],
        hour: Int = 9,
        minute: Int = 0,
        language: String = "de",
        trainedDates: Set<Date> = [],
        weeksAhead: Int = 4,
        now: Date = Date()
    ) {
        let center = UNUserNotificationCenter.current()

        // Vorherige Erinnerungen entfernen
        cancelWorkoutDayReminders()

        guard !days.isEmpty else { return }

        let isEn = language == "en"
        let title = isEn ? "Workout Day! 💪" : "Trainingstag! 💪"
        let body = isEn
            ? "Your training session is ready. Let's make progress today!"
            : "Dein Trainingsplan wartet auf dich. Zeit für progressive Überlastung!"

        let dates = Self.upcomingReminderDates(
            days: days, hour: hour, minute: minute,
            weeksAhead: weeksAhead, from: now, trainedDates: trainedDates
        )

        for date in dates {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.workoutReminderId(for: date),
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    /*
      Welche Zeitpunkte überhaupt in Frage kommen.

      Rein gerechnet und ohne Benachrichtigungssystem — so lässt sich die
      Regel „nur künftige Termine, und keiner an einem Tag, an dem schon
      trainiert wurde" einzeln prüfen.
    */
    public static func upcomingReminderDates(
        days: [String],
        hour: Int,
        minute: Int,
        weeksAhead: Int,
        from now: Date,
        trainedDates: Set<Date> = [],
        calendar: Calendar = .current
    ) -> [Date] {
        let weekdayNumbers = Set(days.compactMap(weekdayNumber(for:)))
        guard !weekdayNumbers.isEmpty, weeksAhead > 0 else { return [] }

        let trainedDays = Set(trainedDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        var result: [Date] = []

        for offset in 0..<(weeksAhead * 7) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard weekdayNumbers.contains(calendar.component(.weekday, from: day)) else { continue }
            // An diesem Tag steht das Training schon im Archiv.
            guard !trainedDays.contains(calendar.startOfDay(for: day)) else { continue }
            guard let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            // Neun Uhr heute ist um zehn kein Termin mehr.
            guard fireDate > now else { continue }
            result.append(fireDate)
        }

        return result
    }

    /// Der Name trägt das Datum, damit sich genau ein Tag zurückziehen lässt.
    public static func workoutReminderId(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%@%04d-%02d-%02d",
            workoutReminderPrefix, c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
    }

    /// Zieht die Erinnerung eines einzelnen Tages zurück — aufgerufen, sobald
    /// das Training dieses Tages im Archiv steht.
    public func cancelWorkoutReminder(on date: Date) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.workoutReminderId(for: date)])
    }

    public func cancelWorkoutDayReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let reminderIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.workoutReminderPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: reminderIds)
        }
    }

    // MARK: - Shake nach dem Training

    private static let proteinShakeId = "kraftwuerfel.nutrition.proteinShake"

    /*
      Eine halbe Stunde nach dem Training an den Shake erinnern.

      Bewusst ein einzelner, zeitversetzter Auslöser und kein wiederkehrender:
      Er hängt am Ende einer konkreten Einheit, nicht am Kalender. Wer zweimal
      am Tag trainiert, bekommt die Erinnerung zum zweiten Training — der
      vorherige Auftrag wird vorher zurückgezogen, damit nicht zwei
      Meldungen kurz hintereinander eintreffen.

      Ohne Erlaubnis passiert schlicht nichts. Das ist kein Fehlerfall: Der
      Nutzer hat Benachrichtigungen abgelehnt, und das Training ist trotzdem
      gelaufen.
    */
    public func scheduleProteinShakeReminder(
        afterMinutes minutes: Int = 30,
        language: String = "de"
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.proteinShakeId])

        guard minutes > 0 else { return }

        let isEn = language == "en"
        let content = UNMutableNotificationContent()
        content.title = isEn ? "Time for your shake 🥤" : "Zeit für deinen Shake 🥤"
        content.body = isEn
            ? "Half an hour since your session — don't forget your protein for recovery."
            : "Eine halbe Stunde nach dem Training — vergiss dein Protein für die Regeneration nicht."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(minutes * 60),
            repeats: false
        )
        center.add(UNNotificationRequest(identifier: Self.proteinShakeId, content: content, trigger: trigger))
    }

    public func cancelProteinShakeReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.proteinShakeId])
    }

    // MARK: - Challenge-Erinnerungen

    private static let challengeReminderId = "kraftwuerfel.challenge.dailyReminder"

    public func scheduleChallengeReminder(
        hour: Int = 9,
        minute: Int = 0,
        challengeTitle: String = "Challenge",
        dayNumber: Int = 1,
        totalDays: Int = 30,
        language: String = "de"
    ) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.challengeReminderId])

        let isEn = language == "en"
        let title = isEn ? "🔥 Daily Challenge: Day \(dayNumber)/\(totalDays)" : "🔥 Tägliche Challenge: Tag \(dayNumber)/\(totalDays)"
        let body = isEn
            ? "Your \(challengeTitle) is waiting! Take 5-10 minutes and smash your daily goal."
            : "Deine \(challengeTitle) wartet! Nimm dir 5-10 Minuten und zieh dein Tagesziel durch."

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.challengeReminderId,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    public func cancelChallengeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.challengeReminderId])
    }

    private func weekdayToCalendarNumber(_ day: String) -> Int? {
        Self.weekdayNumber(for: day)
    }

    static func weekdayNumber(for day: String) -> Int? {
        switch day {
        case "So": return 1
        case "Mo": return 2
        case "Di": return 3
        case "Mi": return 4
        case "Do": return 5
        case "Fr": return 6
        case "Sa": return 7
        default:   return nil
        }
    }

    // MARK: - Satzpause-Timer

    public func scheduleRestCompleteNotification(
        seconds: Int,
        nextSet: Int,
        exerciseName: String,
        language: String = "de"
    ) {
        guard seconds > 0 else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.restNotificationId])

        let isEn = language == "en"
        let title = isEn ? "Rest is up! 🔥" : "Pause vorbei! 🔥"
        let body = isEn
            ? "Time for Set \(nextSet) of \(exerciseName). Let's go!"
            : "Weiter geht's mit Satz \(nextSet) von \(exerciseName). Gib Gas!"

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.restNotificationId,
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    public func cancelRestTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.restNotificationId])
    }

    // MARK: - Akustischer Countdown (5, 4, 3, 2, 1, LOS!)

    /// Spielt einen präzisen Countdown-Ping (5, 4, 3, 2, 1) ab
    public func playCountdownTick(secondsRemaining: Int) {
        guard secondsRemaining >= 1 && secondsRemaining <= 5 else { return }

        // Haptik für jeden Countdown-Schritt
        let feedback = UIImpactFeedbackGenerator(style: secondsRemaining == 1 ? .heavy : .medium)
        feedback.impactOccurred()

        // Heller System-Ding-Ton (1103 = Tink / Ping)
        AudioServicesPlaySystemSound(1103)
    }

    /// Wird aufgerufen, wenn die Pause im Vordergrund abläuft (0s -> Signalton + "LOS!")
    public func playRestFinishedCues(language: String = "de") {
        // Haptisches Erfolgs-Feedback
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Kräftiger Signalton zum Pausenende
        AudioServicesPlaySystemSound(1025)

        // Sprachausgabe "Los!" / "Go!"
        let isEn = language == "en"
        let utterance = AVSpeechUtterance(string: isEn ? "Go!" : "Los!")
        utterance.voice = AVSpeechSynthesisVoice(language: isEn ? "en-US" : "de-DE")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.15
        utterance.pitchMultiplier = 1.1
        utterance.volume = 1.0

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        speechSynthesizer.speak(utterance)
    }
}
