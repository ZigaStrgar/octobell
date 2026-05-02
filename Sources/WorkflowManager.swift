import Foundation
import Combine
import SwiftUI

@MainActor
class WorkflowManager: ObservableObject {
    @Published var workflows: [GHWorkflowRun] = []
    @Published var currentUser: GHActor?
    @Published var allRepositories: [GHRepository] = []
    @Published var disabledRepositories: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(disabledRepositories), forKey: "DisabledRepositories")
        }
    }
    
    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "DisabledRepositories") {
            self.disabledRepositories = Set(saved)
        }
    }
    @Published var isRefreshing = false
    @Published var lastError: String?
    @Published var lastRefreshedAt: Date?
    private var consecutiveUnsuccessfulRefreshes = 0
    
    // Derived states
    var activeWorkflows: [GHWorkflowRun] { workflows.filter { $0.isRunning } }
    var hasActiveWorkflows: Bool { !activeWorkflows.isEmpty }
    
    private var timerTask: Task<Void, Never>?
    private var fastTimerTask: Task<Void, Never>?
    private var refreshInterval: TimeInterval {
        return TimeInterval(SettingsManager.shared.refreshIntervalMinutes * 60)
    }
    private let fastRefreshInterval: TimeInterval = 20 // 20 seconds
    
    func startPolling() {
        stopPolling()
        
        timerTask = Task {
            while !Task.isCancelled {
                await refreshWorkflows()
                try? await Task.sleep(nanoseconds: UInt64(refreshInterval) * 1_000_000_000)
            }
        }
        
        fastTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(fastRefreshInterval) * 1_000_000_000)
                await refreshActiveWorkflows()
            }
        }
    }
    
    func stopPolling() {
        timerTask?.cancel()
        timerTask = nil
        fastTimerTask?.cancel()
        fastTimerTask = nil
    }
    
    func refreshActiveWorkflows() async {
        let currentActive = activeWorkflows
        guard !currentActive.isEmpty else { return }
        
        let client = GitHubClient.shared
        
        await withTaskGroup(of: GHWorkflowRun?.self) { group in
            for run in currentActive {
                group.addTask {
                    return try? await client.fetchWorkflowRun(forRepo: run.repository.fullName, runId: run.id)
                }
            }
            
            for await updatedRun in group {
                if let updated = updatedRun {
                    if let idx = self.workflows.firstIndex(where: { $0.id == updated.id }) {
                        self.workflows[idx] = updated
                    }
                }
            }
        }
        self.lastRefreshedAt = Date()
    }
    
    func refreshWorkflows(isManual: Bool = false) async {
        isRefreshing = true
        lastError = nil
        
        let bypassCache = consecutiveUnsuccessfulRefreshes >= 5
        
        do {
            let client = GitHubClient.shared
            let currentActor = try await client.fetchCurrentUser(ignoreCache: bypassCache)
            self.currentUser = currentActor
            let username = currentActor.login
            
            let repos = try await client.fetchRepositories(ignoreCache: bypassCache)
            self.allRepositories = repos
            
            var allWorkflows: [GHWorkflowRun] = []
            
            for repo in repos {
                if disabledRepositories.contains(repo.fullName) { continue }
                
                // Short circuit if repo isn't active or we only care about specific ones. 
                // For a true v1, iterating all repositories is fine if < 50.
                let fetchedRuns = try? await client.fetchWorkflowRuns(forRepo: repo.fullName, actor: username, ignoreCache: bypassCache)
                if let fetchedRuns = fetchedRuns, !fetchedRuns.isEmpty {
                    // API uses ?actor filter, but we explicitly enforce it here to be robust
                    let filtered = fetchedRuns.filter { $0.actor?.login == username }
                    
                    allWorkflows.append(contentsOf: filtered)
                } else {
                    let maxLimit = SettingsManager.shared.runsToFetch
                    let existingForRepo = self.workflows.filter { $0.repository.fullName == repo.fullName }
                    allWorkflows.append(contentsOf: existingForRepo.prefix(maxLimit))
                }
            }
            
            // Sort by updated_at descending
            let formatter = ISO8601DateFormatter()
            allWorkflows.sort {
                let date1 = formatter.date(from: $0.updatedAt) ?? Date.distantPast
                let date2 = formatter.date(from: $1.updatedAt) ?? Date.distantPast
                return date1 > date2
            }
            
            let isUnchanged = self.workflows.count == allWorkflows.count && zip(self.workflows, allWorkflows).allSatisfy { 
                $0.id == $1.id && $0.status == $1.status && $0.updatedAt == $1.updatedAt 
            }
            
            if isManual {
                if isUnchanged {
                    consecutiveUnsuccessfulRefreshes += 1
                } else {
                    consecutiveUnsuccessfulRefreshes = 0
                }
            } else {
                if !isUnchanged {
                    consecutiveUnsuccessfulRefreshes = 0
                }
            }
            
            if bypassCache {
                consecutiveUnsuccessfulRefreshes = 0
            }
            
            MetricsManager.shared.trackWorkflows(allWorkflows)
            self.evaluateNotifications(oldWorkflows: self.workflows, newWorkflows: allWorkflows)
            self.workflows = allWorkflows
            self.lastRefreshedAt = Date()
            
        } catch {
            self.lastError = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    private func evaluateNotifications(oldWorkflows: [GHWorkflowRun], newWorkflows: [GHWorkflowRun]) {
        let oldDict = Dictionary(grouping: oldWorkflows, by: { $0.id }).compactMapValues { $0.first }
        
        for newRun in newWorkflows {
            if let oldRun = oldDict[newRun.id] {
                let wasActive = oldRun.status == "queued" || oldRun.status == "in_progress"
                let isComplete = newRun.status == "completed"
                
                if wasActive && isComplete {
                    NotificationManager.shared.dispatchNotification(for: newRun)
                }
            }
        }
    }
}
