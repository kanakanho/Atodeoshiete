import Combine
import Foundation
import UIKit
import UserNotifications

enum ReminderScheduleMode: String {
    case afterMinutes
    case atTime
}

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

    func scheduleReminder(
        title: String,
        body: String,
        iconType: ReminderIconType,
        emoji: String,
        mode: ReminderScheduleMode,
        minutesFromNow: Int,
        secondsFromNow: Int,
        hour: Int,
        minute: Int
    ) {
        lastError = nil

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = UNMutableNotificationContent()
        content.title = trimmedTitle.isEmpty ? "あとでおしえて" : trimmedTitle
        content.body = trimmedBody.isEmpty ? "設定したメッセージがありません" : trimmedBody
        content.sound = .default

        if let attachment = makeIconAttachment(iconType: iconType, emoji: emoji) {
            content.attachments = [attachment]
        }

        let trigger: UNNotificationTrigger
        let fireDate: Date?

        switch mode {
        case .afterMinutes:
            let totalSeconds = TimeInterval(max(1, minutesFromNow * 60 + secondsFromNow))
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: totalSeconds, repeats: false)
            fireDate = Date().addingTimeInterval(totalSeconds)
        case .atTime:
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let calendarTrigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            trigger = calendarTrigger
            fireDate = calendarTrigger.nextTriggerDate()
        }

        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        center.add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                } else {
                    self?.lastScheduledFireDate = fireDate
                }
            }
        }
    }

    func cancelScheduledReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
        lastScheduledFireDate = nil
    }

    // UNNotificationAttachment moves the file it is given into its own storage,
    // so a fresh temp copy is made each time rather than handing over the persisted photo file.
    private func makeIconAttachment(iconType: ReminderIconType, emoji: String) -> UNNotificationAttachment? {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)) != nil else {
            return nil
        }
        let fileURL = tmpDir.appendingPathComponent("icon.jpg")

        let imageData: Data?
        switch iconType {
        case .photo:
            imageData = ReminderIconStore.hasPhoto ? try? Data(contentsOf: ReminderIconStore.photoURL) : nil
        case .emoji:
            imageData = ReminderIconStore.emojiImage(emoji).jpegData(compressionQuality: 0.9)
        }

        guard let imageData, (try? imageData.write(to: fileURL)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: UUID().uuidString, url: fileURL, options: nil)
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
