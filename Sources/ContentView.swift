import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue:  Double(b) / 255, opacity: Double(a) / 255)
    }
}

struct AppTheme {
    private static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static var primary: Color          { isDark ? Color(hex: "#adc6ff") : Color(hex: "#005bc1") }
    static var primaryContainer: Color { isDark ? Color(hex: "#003580") : Color(hex: "#d8e2ff") }
    static var blue: Color             { isDark ? Color(hex: "#b0c6ff") : Color(hex: "#003889") }
    static var secondary: Color        { isDark ? Color(hex: "#6cdf80") : Color(hex: "#006e2c") }
    static var secondaryContainer: Color { isDark ? Color(hex: "#005321") : Color(hex: "#88fb99") }
    static var tertiary: Color         { isDark ? Color(hex: "#f5c96a") : Color(hex: "#7e5800") }
    static var tertiaryContainer: Color { isDark ? Color(hex: "#5c4000") : Color(hex: "#f5b63c") }
    static var error: Color            { isDark ? Color(hex: "#ffb4ab") : Color(hex: "#9f403d") }
    static var errorContainer: Color   { isDark ? Color(hex: "#7a2e2b") : Color(hex: "#fe8983") }

    static var surface: Color                { isDark ? Color(hex: "#131318") : Color(hex: "#faf9fe") }
    static var onSurface: Color              { isDark ? Color(hex: "#e3e2ea") : Color(hex: "#2e323d") }
    static var onSurfaceVariant: Color       { isDark ? Color(hex: "#c5c6d0") : Color(hex: "#5b5f6b") }
    static var surfaceContainerLow: Color    { isDark ? Color(hex: "#1d1d23") : Color(hex: "#f3f3fa") }
    static var surfaceContainerLowest: Color { isDark ? Color(hex: "#0e0e13") : Color(hex: "#ffffff") }
    static var surfaceContainerHigh: Color   { isDark ? Color(hex: "#33333b") : Color(hex: "#e6e8f4") }
    static var surfaceContainerHighest: Color { isDark ? Color(hex: "#3e3e46") : Color(hex: "#dfe2f0") }
    static var outlineVariant: Color         { isDark ? Color(hex: "#46464f") : Color(hex: "#aeb1bf") }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
        func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

extension GHWorkflowRun {
    var statusIcon: String {
        switch status {
        case "queued", "in_progress": return "arrow.triangle.2.circlepath"
        case "completed":
            return conclusion == "success" ? "checkmark.circle.fill" : "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    var themeColor: Color {
        switch status {
        case "queued", "in_progress": return AppTheme.tertiary
        case "completed":
            return conclusion == "success" ? AppTheme.secondary : AppTheme.error
        default: return AppTheme.onSurfaceVariant
        }
    }
    
    var themeContainerColor: Color {
        switch status {
        case "queued", "in_progress": return AppTheme.tertiaryContainer.opacity(0.3)
        case "completed":
            return conclusion == "success" ? AppTheme.secondaryContainer : AppTheme.errorContainer
        default: return AppTheme.surfaceContainerHighest
        }
    }
}



struct WorkflowRow: View {
    let workflow: GHWorkflowRun
    @State private var isHovered = false
    @State private var hiddenActionStatus: String? = nil
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(workflow.themeContainerColor)
                    .frame(width: 24, height: 24)
                Image(systemName: workflow.statusIcon)
                    .foregroundColor(workflow.themeColor)
                    .font(.system(size: 14))
                    .accessibilityHidden(true)
            }
            .padding(.top, 2)
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title and Status
                HStack {
                    Text(workflow.name)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(AppTheme.onSurface)
                        .lineLimit(1)
                    Spacer()
                    let stateText = workflow.status == "in_progress" ? "Running" : (workflow.conclusion ?? workflow.status).capitalized
                    Text(stateText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(workflow.themeColor)
                }
                
                // Branch Info
                HStack(spacing: 4) {
                    Image(systemName: "arrow.trianglehead.branch")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .accessibilityHidden(true)
                    Text(workflow.headBranch)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .lineLimit(1)
                        
                    Spacer()
                    actionButton
                }
            }
        }
        .padding(12)
        .background(isHovered ? AppTheme.surfaceContainerLowest : AppTheme.surfaceContainerLowest.opacity(0.6))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(workflow.name) workflow on branch \(workflow.headBranch)")
        .accessibilityValue(workflow.status == "in_progress" ? "Running" : (workflow.conclusion ?? workflow.status).capitalized)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens workflow run details in browser")
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            if let url = URL(string: workflow.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if hiddenActionStatus != workflow.status {
            if workflow.status == "completed" && workflow.conclusion == "failure" {
                Button(action: {
                    Task {
                        do {
                            try await GitHubClient.shared.retryFailedWorkflow(forRepo: workflow.repository.fullName, runId: workflow.id)
                            hiddenActionStatus = workflow.status
                        } catch {
                            AppLogger.log("RETRY FAILED")
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("RE-RUN")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.surfaceContainerHigh)
                    .foregroundColor(AppTheme.onSurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.outlineVariant.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Re-run workflow")
                .accessibilityHint("Attempts to run this workflow again")
            } else if workflow.status == "in_progress" || workflow.status == "queued" {
                Button(action: {
                    Task {
                        do {
                            try await GitHubClient.shared.cancelWorkflow(forRepo: workflow.repository.fullName, runId: workflow.id)
                            hiddenActionStatus = workflow.status
                        } catch {
                            AppLogger.log("CANCEL FAILED")
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("CANCEL")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.surfaceContainerHigh)
                    .foregroundColor(AppTheme.error)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.error.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel workflow")
                .accessibilityHint("Stops this workflow run")
            }
        }
    }
}

struct RepositoryGroupView: View {
    let repoName: String
    let runs: [GHWorkflowRun]
    @Binding var isExpanded: Bool
    
    var body: some View {
        let activeCount = runs.filter { $0.isRunning }.count
        
        VStack(spacing: 4) {
            Button(action: {
                withAnimation { isExpanded.toggle() }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .frame(width: 12)
                        .accessibilityHidden(true)
                    
                    Text(repoName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(AppTheme.onSurfaceVariant)
                    
                    Spacer()
                    
                    
                    if activeCount > 0 {
                        Text("\(activeCount) Active")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.surfaceContainerHighest)
                            .foregroundColor(AppTheme.onSurfaceVariant)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeCount > 0 ? "Repository \(repoName), \(activeCount) Active runs" : "Repository \(repoName)")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Toggles visibility of runs for this repository")
            
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(runs) { run in
                        WorkflowRow(workflow: run)
                    }
                }
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let text: String
    let isActive: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    private var currentColor: Color {
        if isActive {
            return AppTheme.primary
        } else if isHovering {
            return AppTheme.onSurface
        } else {
            return AppTheme.onSurfaceVariant
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(currentColor)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.system(size: 9, weight: isActive ? .bold : .medium))
                    .foregroundColor(currentColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(text) Tab")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Switches to the \(text) section")
        .padding(4)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

enum AppTab {
    case runs, repos, profile
}

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @EnvironmentObject var workflowManager: WorkflowManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var expandedRepos: Set<String> = []
    @State private var selectedTab: AppTab = .runs
    @State private var isHoveringRefresh = false
    @State private var isHoveringLogout = false

    var body: some View {
        Group {
            if authManager.state == .authenticated {
                ZStack {
                    VisualEffectView(material: .popover, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // TopAppBar
                        HStack {
                            HStack(spacing: 8) {
                                Image("Octobell_Icon_Blue")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(AppTheme.blue)
                                    .accessibilityLabel("OctoBell Logo")
                                    .accessibilityAddTraits(.isImage)
                                HStack(spacing: 0) {
                                    Text("Octo")
                                        .font(.system(size: 20, weight: .regular, design: .default))
                                        .foregroundColor(AppTheme.onSurface)
                                    Text("Bell")
                                        .font(.system(size: 20, weight: .semibold, design: .default))
                                        .foregroundColor(AppTheme.blue)
                                }
                                .accessibilityElement(children: .combine)
                            }
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: {
                                    Task {
                                        await workflowManager.refreshWorkflows(isManual: true)
                                    }
                                }) {
                                    if workflowManager.isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 16, height: 16)
                                    } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.onSurfaceVariant)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Refresh")
                                .accessibilityHint("Fetches the latest workflow runs")
                                .keyboardShortcut("r", modifiers: .command)
                                .disabled(workflowManager.isRefreshing)
                                .help("Refresh runs (⌘R)")
                                .padding(6)
                                .background(isHoveringRefresh ? AppTheme.outlineVariant.opacity(0.3) : Color.clear)
                                .cornerRadius(6)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        isHoveringRefresh = hovering
                                    }
                                }
                                
                                Button(action: {
                                    NSApplication.shared.terminate(nil)
                                }) {
                                    Image(systemName: "power")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppTheme.error)
                                        .accessibilityHidden(true)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Quit OctoBell")
                                .accessibilityHint("Terminates the application")
                                .help("Quit")
                                .padding(6)
                                .background(isHoveringLogout ? AppTheme.outlineVariant.opacity(0.3) : Color.clear)
                                .cornerRadius(6)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        isHoveringLogout = hovering
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        
                        // Main Content Area
                        switch selectedTab {
                        case .runs:
                            RunsTabView(
                                searchText: $searchText,
                                expandedRepos: $expandedRepos
                            )
                        case .repos:
                            ReposTabView()
                        case .profile:
                            ProfileTabView {
                                authManager.logout()
                            }
                        }
                        
                        Divider()
                            .background(AppTheme.outlineVariant.opacity(0.3))
                        
                        // Sync Footer
                        HStack {
                            if workflowManager.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 14, height: 14)
                                Text("Syncing...")
                            } else if let lastRefresh = workflowManager.lastRefreshedAt {
                                Text("Updated: \(lastRefresh, style: .time)")
                            } else {
                                Text("Waiting...")
                            }
                            Spacer()
                            if UserDefaults.standard.bool(forKey: "Core_DeveloperMode") {
                                if let lastRefresh = workflowManager.lastRefreshedAt {
                                    let nextCycle = lastRefresh.addingTimeInterval(workflowManager.hasActiveWorkflows ? 20 : TimeInterval(SettingsManager.shared.refreshIntervalMinutes * 60))
                                    Text("Next poll: \(nextCycle, style: .time)")
                                }
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        
                        // Bottom Navigation Extrapolation
                        HStack {
                            Spacer()
                            TabButton(icon: "list.bullet.rectangle", text: "Runs", isActive: selectedTab == .runs) { selectedTab = .runs }
                            Spacer()
                            TabButton(icon: "server.rack", text: "Repos", isActive: selectedTab == .repos) { selectedTab = .repos }
                            Spacer()
                            TabButton(icon: "person.circle", text: "Profile", isActive: selectedTab == .profile) { selectedTab = .profile }
                            Spacer()
                        }
                        .padding(.bottom, 10)
                        .padding(.top, 4)
                        .background(AppTheme.surfaceContainerLow.opacity(0.5))
                        .background(
                            Button("") { selectedTab = .profile }
                                .keyboardShortcut(",", modifiers: .command)
                                .hidden()
                        )
                    }
                }
            } else if case .waitingForUser(let userCode, let verificationUri) = authManager.state {
                VStack(spacing: 20) {
                    Image(systemName: "lock.laptopcomputer")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.primary)
                        .accessibilityHidden(true)
                    
                    Text("Device Activation")
                        .font(.title)
                        .bold()
                    
                    Text("Please enter the following code into your browser to authorize OctoBell.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .padding(.horizontal)
                    
                    Text(userCode)
                        .font(.system(size: 32, weight: .heavy, design: .monospaced))
                        .padding()
                        .background(AppTheme.surfaceContainerHigh)
                        .cornerRadius(12)
                        .accessibilityLabel("Activation code: \(userCode)")
                        
                    Button("Copy & Open Browser") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(userCode, forType: .string)
                        if let url = URL(string: verificationUri) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                    .accessibilityHint("Copies the activation code to clipboard and opens the GitHub authorization page in your default browser")
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.surface)
            } else if authManager.state == .requestingCode || authManager.state == .authenticating {
                VStack {
                    ProgressView()
                        .frame(width: 20, height: 20)
                        .scaleEffect(1.2)
                    Text("Connecting to GitHub...")
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.surface)
            } else {
                VStack(spacing: 20) {
                    Image("Octobell_Icon_Blue")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                    
                    Text("Welcome to OctoBell")
                        .font(.title)
                        .bold()
                    
                    if case .error(let err) = authManager.state {
                        Text(err)
                            .foregroundColor(AppTheme.error)
                            .font(.caption)
                    }
                    
                    Text("Authenticate via Device Flow")
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.onSurfaceVariant)
                        .padding(.horizontal)
                    
                    Button("Sign In") {
                        Task {
                            await authManager.startDeviceFlow()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.surface)
            }
        }
        .id(colorScheme)
        .onAppear {
            if authManager.state == .authenticated {
                workflowManager.startPolling()
            }
        }
        .onChange(of: authManager.state) { oldValue, newValue in
            if newValue == .authenticated {
                workflowManager.startPolling()
            } else {
                workflowManager.stopPolling()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gitHubUnauthorized)) { _ in
            authManager.logout()
            workflowManager.stopPolling() // Ensure we stop right away
            workflowManager.workflows = []
        }
    }
}
