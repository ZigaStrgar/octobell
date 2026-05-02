import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized: Bool = false
    
    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        DispatchQueue.main.async {
            Task {
                await self.updateAuthorizationStatus()
            }
        }
    }
    
    func requestPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            self.isAuthorized = granted
        } catch {
            #if DEBUG
            print("Failed to request notification permission: \(error)")
            #endif
        }
    }
    
    func updateAuthorizationStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let status = (settings.authorizationStatus == .authorized)
        if self.isAuthorized != status {
            self.isAuthorized = status
        }
    }
    
    private func formattedConclusion(_ conclusion: String?) -> String {
        guard let conclusion = conclusion else { return "completed" }
        switch conclusion.lowercased() {
        case "success": return "succeeded"
        case "failure": return "failed"
        case "timed_out": return "timed out"
        case "cancelled": return "was cancelled"
        case "action_required": return "requires action"
        case "skipped": return "was skipped"
        case "startup_failure": return "failed at startup"
        default: return conclusion.replacingOccurrences(of: "_", with: " ")
        }
    }
    
    func dispatchNotification(for workflow: GHWorkflowRun) {
        let settings = SettingsManager.shared
        
        let isSuccess = workflow.conclusion == "success"
        let isFailure = workflow.conclusion == "failure" || workflow.conclusion == "timed_out" || workflow.conclusion == "cancelled" || workflow.conclusion == "startup_failure"
        
        if isSuccess && !settings.notifyOnSuccess { return }
        if isFailure && !settings.notifyOnFailure { return }
        if !isSuccess && !isFailure { return } 
        
        let content = UNMutableNotificationContent()
        
        let conclusionText = formattedConclusion(workflow.conclusion)
        let icon = isSuccess ? "✅" : "❌"
        
        content.title = "\(icon) Run \(conclusionText.capitalized)"
        content.subtitle = workflow.repository.fullName
        content.body = "Run '\(workflow.name)' \(conclusionText)."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "workflow-\(workflow.id)-\(workflow.updatedAt)", content: content, trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                #if DEBUG
                print("Failed to dispatch local notification: \(error)")
                #endif
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}
