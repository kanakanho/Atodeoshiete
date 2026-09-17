import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastScheduledFireDate: Date?
    @Published var lastError: String?

    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifier = "com.github.kanakanho.atodeoshiete.reminder"

    override init() {
        super.init()
        center.delegate = self
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        Task {
            let settings = await center.notificationSettings()
            authorizationStatus = settings.authorizationStatus
        }
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .authorized : .denied
        } catch {
            lastError = error.localizedDescription
        }
    }

    func scheduleReminder(icon: String, message: String, secondsFromNow: TimeInterval = 60) {
        lastError = nil

        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = UNMutableNotificationContent()
        content.title = trimmedIcon.isEmpty ? "あとでおしえて" : "\(trimmedIcon) あとでおしえて"
        content.body = trimmedMessage.isEmpty ? "設定したメッセージがありません" : trimmedMessage
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: secondsFromNow, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        center.add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                } else {
                    self?.lastScheduledFireDate = Date().addingTimeInterval(secondsFromNow)
                }
            }
        }
    }

    func cancelScheduledReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        lastScheduledFireDate = nil
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    // 通知はローカルで完結させるため、フォアグラウンド中もバナー表示できるようにしておく。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
