import SwiftUI

struct ReposTabView: View {
    @EnvironmentObject var workflowManager: WorkflowManager

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(workflowManager.allRepositories) { repo in
                    HStack {
                        Text(repo.fullName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.onSurface)
                        Spacer()

                        let isEnabled = !workflowManager.disabledRepositories.contains(repo.fullName)
                        Toggle("", isOn: Binding(
                            get: { isEnabled },
                            set: { enabled in
                                if enabled {
                                    workflowManager.disabledRepositories.remove(repo.fullName)
                                } else {
                                    workflowManager.disabledRepositories.insert(repo.fullName)
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(AppTheme.primary)
                        .accessibilityLabel("Enable \(repo.fullName) repository")
                        .accessibilityHint("Controls whether workflows are fetched for this repository")
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                    }
                    .padding()
                    .background(AppTheme.surfaceContainerLowest)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }
}
