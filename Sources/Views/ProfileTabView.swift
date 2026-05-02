import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var workflowManager: WorkflowManager
    @ObservedObject private var metrics = MetricsManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var notifications = NotificationManager.shared
    var onLogout: () -> Void
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "Version: \(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar & Username
                if let user = workflowManager.currentUser {
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(AppTheme.onSurfaceVariant)
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .padding(.top, 24)
                        .accessibilityLabel("User Avatar")

                        Text("@\(user.login)")
                            .font(.headline)
                            .foregroundColor(AppTheme.onSurface)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(AppTheme.primary)
                        .padding(.top, 24)
                        .accessibilityLabel("User Avatar")
                }

                // Metrics Cards
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Runs")
                            .font(.caption)
                            .foregroundColor(AppTheme.onSurfaceVariant)

                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(AppTheme.primary)
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text("\(metrics.totalRunsProcessed)")
                                .font(.title)
                                .bold()
                                .foregroundColor(AppTheme.onSurface)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceContainerLowest)
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last 7 Days")
                            .font(.caption)
                            .foregroundColor(AppTheme.onSurfaceVariant)

                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(AppTheme.primary)
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text("\(metrics.runsInLastSevenDays)")
                                .font(.title)
                                .bold()
                                .foregroundColor(AppTheme.onSurface)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surfaceContainerLowest)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)

                // Preferences
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferences")
                        .font(.headline)
                        .foregroundColor(AppTheme.onSurface)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        // Refresh Interval
                        HStack {
                            Text("Refresh Interval (mins)")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { settings.refreshIntervalMinutes },
                                set: { val in DispatchQueue.main.async { settings.refreshIntervalMinutes = val } }
                            )) {
                                Text("1").tag(1)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                                Text("5").tag(5)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                                Text("10").tag(10)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                            }
                            .accessibilityLabel("Refresh Interval")
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        .padding()

                        Divider()

                        // Runs per Repo
                        HStack {
                            Text("Runs per Repository")
                            Spacer()
                            Picker("", selection: Binding(
                                get: { settings.runsToFetch },
                                set: { val in DispatchQueue.main.async { settings.runsToFetch = val } }
                            )) {
                                Text("10").tag(10)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                                Text("20").tag(20)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                                Text("30").tag(30)
                                    .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                            }
                            .accessibilityLabel("Runs per Repository")
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        .padding()

                        Divider()

                        // Notifications disabled warning
                        if !notifications.isAuthorized {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text("Notifications disabled")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.onSurfaceVariant)
                                Spacer()
                                Button("Enable") {
                                    Task { await notifications.requestPermissions() }
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                            .padding()
                            Divider()
                        }

                        // Notify on Success
                        HStack {
                            Text("Notify on Success")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { settings.notifyOnSuccess },
                                set: { val in DispatchQueue.main.async { settings.notifyOnSuccess = val } }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(AppTheme.primary)
                            .accessibilityLabel("Notify on Success")
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        .padding()

                        Divider()

                        // Notify on Failure
                        HStack {
                            Text("Notify on Failure")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { settings.notifyOnFailure },
                                set: { val in DispatchQueue.main.async { settings.notifyOnFailure = val } }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(AppTheme.primary)
                            .accessibilityLabel("Notify on Failure")
                            .onHover { hovering in
                                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                            }
                        }
                        .padding()
                    }
                    .background(AppTheme.surfaceContainerLowest)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
                
                // Developer Options
                if settings.isDeveloperModeEnabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Developer Options")
                            .font(.headline)
                            .foregroundColor(AppTheme.onSurface)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            HStack {
                                Text("Enable Debug Logs")
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { settings.isDebugLogsEnabled },
                                    set: { val in DispatchQueue.main.async { settings.isDebugLogsEnabled = val } }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .tint(AppTheme.primary)
                                .accessibilityLabel("Enable Debug Logs")
                                .onHover { hovering in
                                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                            .padding()
                        }
                        .background(AppTheme.surfaceContainerLowest)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                }

                // Logout
                Button(action: onLogout) {
                    Text("Log Out from OctoBell")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.error)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.error.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log Out")
                .accessibilityHint("Disconnects your GitHub account")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Text(appVersion)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 20)
            }
        }
        .background(
            Button("") {
                DispatchQueue.main.async {
                    settings.isDeveloperModeEnabled.toggle()
                }
            }
            .keyboardShortcut("d", modifiers: [.option])
            .hidden()
        )
    }
}
