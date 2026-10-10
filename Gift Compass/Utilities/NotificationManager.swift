import Foundation
import UserNotifications

enum NotificationManager {
    static let settingKey = "giftForYou.setting.birthdayReminders"
    private static let identifierPrefix = "giftForYou.birthday."

    static func requestAndSchedule(for people: [GiftPerson]) async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return false }
            await schedule(for: people)
            return true
        } catch {
            return false
        }
    }

    static func schedule(for people: [GiftPerson]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for person in people {
            guard let birthday = person.birthdayDate else { continue }
            let date = Calendar.current.date(byAdding: .day, value: -1, to: birthday) ?? birthday
            let birthdayParts = Calendar.current.dateComponents([.month, .day], from: date)
            var triggerParts = DateComponents()
            triggerParts.month = birthdayParts.month
            triggerParts.day = birthdayParts.day
            triggerParts.hour = 10

            let content = UNMutableNotificationContent()
            content.title = "A birthday is coming up"
            content.body = "Tomorrow is \(person.name)’s birthday. Open Gift for You to review saved ideas."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: identifierPrefix + person.id.uuidString,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: triggerParts, repeats: true)
            )
            try? await center.add(request)
        }
    }

    static func disable() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
}
