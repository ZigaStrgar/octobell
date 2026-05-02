import Cocoa
import SwiftUI
import UserNotifications
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    let workflowManager = WorkflowManager()
    private var cancellables = Set<AnyCancellable>()
    private var previouslyRunning: Set<Int> = []
    private var unseenCount: Int = 0
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        let retryAction = UNNotificationAction(identifier: "RETRY_ACTION",
                                               title: "Retry Run",
                                               options: [])
        
        let failedCategory = UNNotificationCategory(identifier: "FAILED_RUN",
                                                    actions: [retryAction],
                                                    intentIdentifiers: [],
                                                    options: [])
        
        center.setNotificationCategories([failedCategory])
        
        // Request notification permissions
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            #if DEBUG
            print("Notifications granted: \(granted)")
            #endif
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
        
        // Observe workflow changes to update icon and trigger notifications
        workflowManager.$workflows
            .receive(on: RunLoop.main)
            .sink { [weak self] workflows in
                self?.handleWorkflowUpdates(workflows)
            }
            .store(in: &cancellables)
            
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }
    
    @objc internal func applicationDidResignActive(_ notification: Notification) {
        if popover?.isShown == true {
            popover?.performClose(nil)
        }
    }
    
    private func handleWorkflowUpdates(_ workflows: [GHWorkflowRun]) {
        let currentlyRunning = Set(workflows.filter { $0.isRunning }.map { $0.id })
        
        // Check for completed workflows
        let completed = previouslyRunning.subtracting(currentlyRunning)
        for id in completed {
            if let run = workflows.first(where: { $0.id == id }) {
                triggerNotification(for: run)
            }
        }
        
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
    
    private func formattedStatus(_ statusStr: String) -> String {
        switch statusStr.lowercased() {
        case "success": return "succeeded"
        case "failure": return "failed"
        case "timed_out": return "timed out"
        case "cancelled": return "was cancelled"
        case "action_required": return "requires action"
        case "skipped": return "was skipped"
        case "startup_failure": return "failed at startup"
        default: return statusStr.replacingOccurrences(of: "_", with: " ")
        }
    }
    
    private func triggerNotification(for run: GHWorkflowRun) {
        let content = UNMutableNotificationContent()
        let success = run.conclusion == "success"
        let statusStr = run.conclusion ?? run.status
        let pastStatus = formattedStatus(statusStr)
        
        content.title = "Run \(run.name) \(pastStatus)"
        content.body = "On branch \(run.headBranch) • \(run.repository.name)"
        content.sound = .default
        
        content.userInfo = [
            "htmlUrl": run.htmlUrl,
            "runId": run.id,
            "repoFullName": run.repository.fullName
        ]
        
        if !success && statusStr == "failure" {
            content.categoryIdentifier = "FAILED_RUN"
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        #if DEBUG
        print("NOTIFICATION CLICKED. Action: \(response.actionIdentifier) UserInfo: \(userInfo)")
        #endif
        
        if response.actionIdentifier == "RETRY_ACTION" {
            if let repo = userInfo["repoFullName"] as? String,
               let runId = userInfo["runId"] as? Int {
                #if DEBUG
                print("Retry matched for \(repo) ID: \(runId)")
                #endif
                Task {
                    do {
                        try await GitHubClient.shared.retryFailedWorkflow(forRepo: repo, runId: runId)
                        #if DEBUG
                        print("Retry dispatched securely.")
                        #endif
                    } catch {
                        #if DEBUG
                        print("Retry dispatch failed: \(error)")
                        #endif
                    }
                }
            } else {
                #if DEBUG
                print("Retrieval failure: Invalid UserInfo dictionary casting")
                #endif
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let htmlUrlStr = userInfo["htmlUrl"] as? String,
               let url = URL(string: htmlUrlStr) {
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(url)
                }
            }
        }
        
        completionHandler()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                unseenCount = 0
                updateMenuBarIcon(currentlyRunning: previouslyRunning)
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}

