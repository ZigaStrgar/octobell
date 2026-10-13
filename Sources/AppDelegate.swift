import Cocoa
import SwiftUI
import UserNotifications
import Combine

enum MenuBarStatus: Equatable {
    case idle
    case running(count: Int)
    case failure(count: Int)
    case success
    case error(message: String)
    
    var accessibilityDescription: String {
        switch self {
        case .idle:
            return "OctoBell, Idle"
        case .running(let count):
            return "OctoBell, \(count) running"
        case .failure(let count):
            return "OctoBell, \(count) failed"
        case .success:
            return "OctoBell, workflows succeeded"
        case .error:
            return "OctoBell, connection error"
        }
    }
    
    var tooltipDescription: String {
        switch self {
        case .idle:
            return "OctoBell — Idle"
        case .running(let count):
            let unit = count == 1 ? "workflow" : "workflows"
            return "OctoBell — \(count) \(unit) in progress"
        case .failure(let count):
            let unit = count == 1 ? "workflow" : "workflows"
            return "OctoBell — \(count) \(unit) failed"
        case .success:
            return "OctoBell — Workflows succeeded"
        case .error(let message):
            return "OctoBell — Error: \(message)"
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    let workflowManager = WorkflowManager()
    private var cancellables = Set<AnyCancellable>()
    private var previouslyRunning: Set<Int> = []
    private var unseenCount: Int = 0
    private var unseenStatus: MenuBarStatus? = nil
    private var animationTimer: Timer?
    private var animationPhase: Int = 0
    private var currentStatus: MenuBarStatus = .idle

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
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        setupSubscriptions()
        updateMenuBarState()
    }
    
    private func setupSubscriptions() {
        // Observe workflow changes to update icon, track unseen count, and animate
        workflowManager.$workflows
            .receive(on: RunLoop.main)
            .sink { [weak self] workflows in
                self?.handleWorkflowUpdates(workflows)
            }
            .store(in: &cancellables)

        workflowManager.$lastError
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarState()
            }
            .store(in: &cancellables)

        workflowManager.$disabledRepositories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarState()
            }
            .store(in: &cancellables)

        SettingsManager.shared.$showStatusIndicator
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarState()
            }
            .store(in: &cancellables)
    }

    private func handleWorkflowUpdates(_ workflows: [GHWorkflowRun]) {
        let monitoredRuns = workflows.filter {
            !workflowManager.disabledRepositories.contains($0.repository.fullName)
        }
        let currentlyRunning = Set(monitoredRuns.filter { $0.isRunning }.map { $0.id })
        
        // Check for completed workflows to increment unseen badge count and set unseen status
        let completedIds = previouslyRunning.subtracting(currentlyRunning)
        if !completedIds.isEmpty {
            unseenCount += completedIds.count
            
            let completedRuns = workflows.filter { completedIds.contains($0.id) }
            let failedRuns = completedRuns.filter { run in
                let c = run.conclusion?.lowercased() ?? ""
                return c == "failure" || c == "timed_out" || c == "startup_failure" || c == "cancelled"
            }
            
            if !failedRuns.isEmpty {
                unseenStatus = .failure(count: failedRuns.count)
            } else {
                unseenStatus = .success
            }
        }
        
        previouslyRunning = currentlyRunning
        updateMenuBarState()
    }
    
    private func determineStatus() -> MenuBarStatus {
        if let error = workflowManager.lastError {
            return .error(message: error)
        }
        
        let monitoredRuns = workflowManager.workflows.filter {
            !workflowManager.disabledRepositories.contains($0.repository.fullName)
        }
        
        let activeRuns = monitoredRuns.filter { $0.isRunning }
        if !activeRuns.isEmpty {
            return .running(count: activeRuns.count)
        }
        
        // If there are unseen completed runs, show their status until the user opens the popover
        if let unseen = unseenStatus {
            return unseen
        }
        
        return .idle
    }
    
    private func updateMenuBarState() {
        currentStatus = determineStatus()
        
        let shouldAnimate: Bool
        if case .running = currentStatus {
            shouldAnimate = SettingsManager.shared.showStatusIndicator
        } else {
            shouldAnimate = false
        }
        
        if shouldAnimate {
            startAnimationIfNeeded()
        } else {
            stopAnimation()
        }
        
        renderStatusItem()
    }
    
    private func startAnimationIfNeeded() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.animationPhase = (self.animationPhase + 1) % 2
                self.renderStatusItem()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }
    
    private func renderStatusItem() {
        guard let button = statusItem.button else { return }
        
        let settings = SettingsManager.shared
        button.toolTip = currentStatus.tooltipDescription
        button.setAccessibilityLabel(currentStatus.accessibilityDescription)
        
        let image = makeMenuBarImage(status: currentStatus, phase: animationPhase, showIndicator: settings.showStatusIndicator)
        image.accessibilityDescription = currentStatus.accessibilityDescription
        button.image = image
        
        if unseenCount > 0 {
            button.title = " \(unseenCount)"
        } else {
            button.title = ""
        }
    }
    
    private func makeMenuBarImage(status: MenuBarStatus, phase: Int, showIndicator: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let base = NSImage(named: "Octobell_Icon_Black") else { return false }
            
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
            
            guard showIndicator else { return true }
            
            let badgeColor: NSColor?
            switch status {
            case .running:
                badgeColor = NSColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1.0) // Amber In-Progress
            case .failure:
                badgeColor = NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1.0) // Red Failure
            case .success:
                badgeColor = NSColor(red: 0.20, green: 0.75, blue: 0.35, alpha: 1.0) // Green Success
            case .error:
                badgeColor = NSColor.systemOrange
            case .idle:
                badgeColor = nil
            }
            
            guard let color = badgeColor else { return true }
            
            // Tint base icon with labelColor for dynamic light/dark appearance
            NSColor.labelColor.set()
            rect.fill(using: .sourceIn)
            
            // Dynamic badge size and breathing pulse when running
            let badgeSize: CGFloat
            let opacity: CGFloat
            if case .running = status {
                badgeSize = (phase % 2 == 0) ? 5.5 : 4.2
                opacity = (phase % 2 == 0) ? 1.0 : 0.7
            } else {
                badgeSize = 5.5
                opacity = 1.0
            }
            
            let xOffset = 18.0 - badgeSize - 0.5
            let yOffset: CGFloat = 0.5
            let badgeRect = NSRect(x: xOffset, y: yOffset, width: badgeSize, height: badgeSize)
            
            // Cutout ring around badge
            let cutoutRect = badgeRect.insetBy(dx: -1.0, dy: -1.0)
            let cutoutPath = NSBezierPath(ovalIn: cutoutRect)
            NSGraphicsContext.current?.compositingOperation = .clear
            cutoutPath.fill()
            
            // Colored status badge dot
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            color.withAlphaComponent(opacity).setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            
            return true
        }
        
        image.isTemplate = !showIndicator || (status == .idle)
        return image
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                unseenCount = 0
                unseenStatus = nil
                updateMenuBarState()
                SettingsManager.shared.refreshLaunchAtLoginStatus()
                
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
