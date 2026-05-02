import SwiftUI

struct RunsTabView: View {
    @EnvironmentObject var workflowManager: WorkflowManager
    @Binding var searchText: String
    @Binding var expandedRepos: Set<String>

    var groupedRepos: [(String, [GHWorkflowRun])] {
        var runs = workflowManager.workflows.filter { !workflowManager.disabledRepositories.contains($0.repository.fullName) }
        if !searchText.isEmpty {
            runs = runs.filter {
                $0.repository.fullName.localizedCaseInsensitiveContains(searchText)
                || $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.headBranch.localizedCaseInsensitiveContains(searchText)
            }
        }
        let repoDict = Dictionary(grouping: runs, by: { $0.repository.fullName })
        return repoDict.sorted(by: { $0.key < $1.key })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Box
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.onSurfaceVariant)
                    .accessibilityHidden(true)
                TextField("Search workflows, repos or branches...", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search workflows")
                    .accessibilityHint("Filter runs by repository, name, or branch")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceContainerLow)
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Runs List
            if workflowManager.workflows.isEmpty && !workflowManager.isRefreshing {
                Spacer()
                Text("No workflows found")
                    .foregroundColor(AppTheme.onSurfaceVariant)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedRepos, id: \.0) { repoName, runs in
                            RepositoryGroupView(
                                repoName: repoName,
                                runs: runs,
                                isExpanded: Binding(
                                    get: { !expandedRepos.contains(repoName) },
                                    set: { expanded in
                                        if expanded { expandedRepos.remove(repoName) }
                                        else { expandedRepos.insert(repoName) }
                                    }
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }
            }
        }
    }
}
