import SwiftUI

@main
struct NewsDigestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - no windows in Scene
        Settings {
            EmptyView()
        }
    }
}
