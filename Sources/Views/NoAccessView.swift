import SwiftUI

struct NoAccessView: View {
    var error: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill((error != nil ? AppTheme.errorContainer : AppTheme.primaryContainer).opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: error != nil ? "exclamationmark.triangle" : "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(error != nil ? AppTheme.error : AppTheme.primary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text(error != nil ? "Sync Error" : "No Repository Access")
                    .font(.title2)
                    .bold()
                    .foregroundColor(AppTheme.onSurface)
                
                Text(error ?? "OctoBell needs permission to access your repositories to monitor workflows. Please grant access in the GitHub App settings.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.onSurfaceVariant)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Button(action: {
                if let url = URL(string: "https://github.com/apps/octobell") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack {
                    Text("Grant Access on GitHub")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
    }
}

#Preview {
    NoAccessView()
        .frame(width: 350, height: 450)
}
