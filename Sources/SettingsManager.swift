import Foundation
import Combine
import AppKit
import ServiceManagement

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var refreshIntervalMinutes: Int {
        didSet { UserDefaults.standard.set(refreshIntervalMinutes, forKey: "Core_RefreshIntervalMinutes") }
    }
    
    @Published var runsToFetch: Int {
        didSet { UserDefaults.standard.set(runsToFetch, forKey: "Core_RunsToFetch") }
    }
    
    @Published var notifyOnSuccess: Bool {
        didSet { UserDefaults.standard.set(notifyOnSuccess, forKey: "Core_NotifySuccess") }
    }
    
    @Published var notifyOnFailure: Bool {
        didSet { UserDefaults.standard.set(notifyOnFailure, forKey: "Core_NotifyFailure") }
    }
    
    @Published var isDeveloperModeEnabled: Bool {
        didSet { UserDefaults.standard.set(isDeveloperModeEnabled, forKey: "Core_DeveloperMode") }
    }
    
    @Published var isDebugLogsEnabled: Bool {
        didSet { UserDefaults.standard.set(isDebugLogsEnabled, forKey: "Core_DebugLogsEnabled") }
    }
    
    @Published var isLaunchAtLoginEnabled: Bool = false
    @Published var launchAtLoginStatus: SMAppService.Status = .notRegistered
    
    private init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "Core_RefreshIntervalMinutes")
        self.refreshIntervalMinutes = savedInterval == 0 ? 5 : savedInterval
        
        let savedRuns = UserDefaults.standard.integer(forKey: "Core_RunsToFetch")
        self.runsToFetch = savedRuns == 0 ? 10 : savedRuns
        
        if UserDefaults.standard.object(forKey: "Core_NotifySuccess") == nil {
            self.notifyOnSuccess = true
        } else {
            self.notifyOnSuccess = UserDefaults.standard.bool(forKey: "Core_NotifySuccess")
        }
        
        if UserDefaults.standard.object(forKey: "Core_NotifyFailure") == nil {
            self.notifyOnFailure = true
        } else {
            self.notifyOnFailure = UserDefaults.standard.bool(forKey: "Core_NotifyFailure")
        }
        
        self.isDeveloperModeEnabled = UserDefaults.standard.bool(forKey: "Core_DeveloperMode")
        self.isDebugLogsEnabled = UserDefaults.standard.bool(forKey: "Core_DebugLogsEnabled")
        
        refreshLaunchAtLoginStatus()
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshLaunchAtLoginStatus()
            }
        }
    }
    
    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        self.launchAtLoginStatus = status
        self.isLaunchAtLoginEnabled = (status == .enabled)
    }
    
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    refreshLaunchAtLoginStatus()
                    return
                }
                try SMAppService.mainApp.register()
                AppLogger.log("Successfully registered launch at login")
            } else {
                if SMAppService.mainApp.status == .notRegistered {
                    refreshLaunchAtLoginStatus()
                    return
                }
                try SMAppService.mainApp.unregister()
                AppLogger.log("Successfully unregistered launch at login")
            }
        } catch {
            AppLogger.log("Failed to \(enabled ? "register" : "unregister") launch at login: \(error.localizedDescription)")
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
        refreshLaunchAtLoginStatus()
    }
    
    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
