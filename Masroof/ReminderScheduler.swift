import UserNotifications

/// Hands the daily reminder's messages to iOS, one notification per coming day.
enum ReminderScheduler {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAccess() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func canNotify(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    /// The app sends no other notifications, so everything pending is the reminder.
    static func clear() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func schedule(_ messages: [ReminderPlan.Message], hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for message in messages {
            // A newer schedule has started; let it write the list.
            if Task.isCancelled { return }
            let content = UNMutableNotificationContent()
            content.title = message.title
            content.body = message.body
            content.sound = .default
            // In the phone's own calendar, which may be Hijri, since that is what the trigger matches against.
            let fire = ReminderPlan.fireDate(day: message.day, hour: hour, minute: minute)
            let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "daily-\(message.day)", content: content, trigger: trigger))
        }
    }
}
