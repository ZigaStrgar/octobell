import SwiftUI

@main
struct OctoBellApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We use Settings instead of WindowGroup to avoid creating a main window at launch
        Settings {
            EmptyView()
        }
    }
}
