import SwiftData
import SwiftUI
import UserNotifications

@main
struct ListingsApp: App {
    @State private var model = AppModel()

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(for: [SavedListing.self, MeetupPlan.self])
    }
}
