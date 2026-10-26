import SwiftUI
import UserNotifications

/// The daily message as a local notification. A repeating trigger would repeat the same text,
/// so the next 14 days are scheduled one by one, each with that day's message.
@MainActor
enum DailyReminder {
    private static let days = 14
    private static var ids: [String] { (0..<days).map { "daily-\($0)" } }

    static func schedule(profile: PetProfile, minutes: Int) async -> Bool {
        guard await requestPermission() else { return false }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)

        let calendar = Calendar.current
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = minutes / 60
            parts.minute = minutes % 60
            guard let fireDate = calendar.date(from: parts), fireDate > .now else { continue }

            let content = makeContent(profile: profile, message: Motivation.message(for: profile, on: fireDate))
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "daily-\(offset)", content: content, trigger: trigger))
        }
        return true
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// One pending alert for when the pet's first level runs low; replaced on every care change.
    static func scheduleCareAlert(profile: PetProfile, need: PetNeed, at date: Date) async -> Bool {
        guard await requestPermission() else { return false }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(profile.name) needs you", bundle: .app)
        content.body = need.line(name: profile.name)
        content.sound = .default
        if let url = petImageFile(profile.pet),
           let attachment = try? UNNotificationAttachment(identifier: "pet", url: url) {
            content.attachments = [attachment]
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "care-alert", content: content, trigger: trigger))
        return true
    }

    static func cancelCareAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["care-alert"])
    }

    static func sendNow(profile: PetProfile) async {
        guard await requestPermission() else { return }
        let content = makeContent(profile: profile, message: Motivation.message(for: profile))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "daily-now", content: content, trigger: trigger))
    }

    private static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private static func makeContent(profile: PetProfile, message: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(profile.name) · \(profile.sign.symbol) \(profile.sign.name)"
        content.body = message
        content.sound = .default
        if let url = petImageFile(profile.pet),
           let attachment = try? UNNotificationAttachment(identifier: "pet", url: url) {
            content.attachments = [attachment]
        }
        return content
    }

    /// Renders the happy pose to a PNG. Each attachment needs its own file, since iOS moves it.
    private static func petImageFile(_ pet: PetKind) -> URL? {
        let renderer = ImageRenderer(content: PixelPetView(kind: pet, frame: 2).frame(width: 256, height: 256))
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pet-\(UUID().uuidString).png")
        return (try? data.write(to: url)) != nil ? url : nil
    }
}

/// Shows notifications as banners even while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
