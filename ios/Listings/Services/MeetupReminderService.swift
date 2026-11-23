import Foundation
import UserNotifications

/// Schedules a local notification one hour before each meetup
/// (or a few seconds from now if the meetup is less than an hour away).
enum MeetupReminderService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule(id: UUID, title: String, spot: String, date: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
        guard date > .now, await requestPermission() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Meetup coming up"
        content.body = "\(title) at \(spot), \(date.formatted(date: .omitted, time: .shortened))"
        content.sound = .default

        let fireDate = max(date.addingTimeInterval(-3600), Date.now.addingTimeInterval(5))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger))
    }

    static func cancel(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}

/// Lets reminders appear as banners while the app is open.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
