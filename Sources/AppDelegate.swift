import Cocoa
import SwiftUI
import UserNotifications
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    let workflowManager = WorkflowManager()
    private var cancellables = Set<AnyCancellable>()
    private var previouslyRunning: Set<Int> = []
    private var unseenCount: Int = 0
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NotificationManager.shared.setupNotificationCenter()
        
        Task {
            await NotificationManager.shared.requestPermissions()
        }
        
        // 1. Create the popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 550)
        popover.behavior = .transient
        // Pass the shared workflowManager to ContentView using environmentObject
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .frame(width: 400, height: 550)
                .environmentObject(workflowManager)
        )
        self.popover = popover
        
        // 2. Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let icon = NSImage(named: "Octobell_Icon_Black")
            icon?.size = NSSize(width: 18, height: 18)
            icon?.isTemplate = true
            button.image = icon
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Observe workflow changes to update icon and badge count
        workflowManager.$workflows
            .receive(on: RunLoop.main)
            .sink { [weak self] workflows in
                self?.handleWorkflowUpdates(workflows)
            }
            .store(in: &cancellables)
    }

    private func handleWorkflowUpdates(_ workflows: [GHWorkflowRun]) {
        let currentlyRunning = Set(workflows.filter { $0.isRunning }.map { $0.id })
        
        // Check for completed workflows to increment unseen badge count
        let completed = previouslyRunning.subtracting(currentlyRunning)
        if !completed.isEmpty {
            unseenCount += completed.count
        }
        
        previouslyRunning = currentlyRunning
        
        updateMenuBarIcon(currentlyRunning: currentlyRunning)
    }
    
    private func updateMenuBarIcon(currentlyRunning: Set<Int>) {
        guard let button = statusItem.button else { return }
        
        if workflowManager.lastError != nil {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Auth Error")
            button.image?.isTemplate = false
            button.title = ""
        } else {
            let icon = NSImage(named: "Octobell_Icon_Black")
            icon?.size = NSSize(width: 18, height: 18)
            icon?.accessibilityDescription = !currentlyRunning.isEmpty ? "Running" : "Idle"
            icon?.isTemplate = true
            button.image = icon
            
            if unseenCount > 0 {
                button.title = " \(unseenCount)"
            } else {
                button.title = ""
            }
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                unseenCount = 0
                updateMenuBarIcon(currentlyRunning: previouslyRunning)
                SettingsManager.shared.refreshLaunchAtLoginStatus()
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
