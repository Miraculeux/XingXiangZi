import Intents
import SwiftUI
import UIKit

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

@main
struct XingXiangZiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
