#if os(iOS)
import Intents
import UIKit
#endif
import SwiftUI

#if os(iOS)
class AppDelegate: NSObject, UIApplicationDelegate {
    let mediaIntentHandler = MediaIntentHandler()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        if intent is INPlayMediaIntent {
            return mediaIntentHandler
        }
        return nil
    }
}
#endif

@main
struct XingXiangZiApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        Window("词牌", id: "cipai") {
            NavigationStack {
                CiPaiListView(dbManager: DatabaseManager.shared)
            }
            .frame(minWidth: 500, minHeight: 600)
        }
        Window("设置", id: "settings") {
            SettingsView()
                .frame(minWidth: 400, minHeight: 300)
        }
        #endif
    }
}
