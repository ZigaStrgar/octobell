import Foundation

@MainActor
class MetricsManager: ObservableObject {
    static let shared = MetricsManager()
    
    @Published private(set) var totalRunsProcessed: Int {
        didSet { UserDefaults.standard.set(totalRunsProcessed, forKey: "Metrics_TotalRuns") }
    }
    
    @Published private(set) var totalAttemptsProcessed: Int {
        didSet { UserDefaults.standard.set(totalAttemptsProcessed, forKey: "Metrics_TotalAttempts") }
    }
    
    // String runId -> Date processed
    @Published private(set) var recentRuns: [String: Date] {
        didSet {
            if let encoded = try? JSONEncoder().encode(recentRuns) {
                UserDefaults.standard.set(encoded, forKey: "Metrics_RecentRuns")
            }
        }
    }
    
    // Computed property for the UI safely tracking up to 7 trailing days
    var runsInLastSevenDays: Int {
        return recentRuns.count
    }
    
    private init() {
        self.totalRunsProcessed = UserDefaults.standard.integer(forKey: "Metrics_TotalRuns")
        self.totalAttemptsProcessed = UserDefaults.standard.integer(forKey: "Metrics_TotalAttempts")
        
        if let data = UserDefaults.standard.data(forKey: "Metrics_RecentRuns"),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            self.recentRuns = decoded
        } else {
            self.recentRuns = [:]
        }
        
        pruneOldRecords()
    }
    
    func trackWorkflows(_ workflows: [GHWorkflowRun]) {
        var didChange = false
        var newlyProcessedRunsCounter = 0
        var newlyProcessedAttemptsCounter = 0
        let now = Date()
        
        for workflow in workflows {
            let runIdKey = String(workflow.id)
            if recentRuns[runIdKey] == nil {
                // First time we are actively tracking/seeing this complete run
                recentRuns[runIdKey] = now
                newlyProcessedRunsCounter += 1
                didChange = true
                
                // Keep attempt count synchronized (Github API base maps this natively)
                newlyProcessedAttemptsCounter += workflow.runAttempt
            }
        }
        
        if didChange {
            pruneOldRecords()
            self.totalRunsProcessed += newlyProcessedRunsCounter
            self.totalAttemptsProcessed += newlyProcessedAttemptsCounter
        }
    }
    
    private func pruneOldRecords() {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let beforeCount = recentRuns.count
        
        // Filter out keys older than 7 days
        recentRuns = recentRuns.filter { $0.value >= sevenDaysAgo }
        
        if recentRuns.count < beforeCount {
            AppLogger.log("Pruned \(beforeCount - recentRuns.count) records from MetricsManager")
        }
    }
}
