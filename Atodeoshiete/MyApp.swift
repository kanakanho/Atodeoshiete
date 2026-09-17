import SwiftUI

@main struct MyApp: App {
    init() {
        // NotificationManager をここで初期化し、通知デリゲートを起動時から有効にする。
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
