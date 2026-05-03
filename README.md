<div align="center">
  <img src="Sources/Assets.xcassets/AppIcon.appiconset/mac_256_2x.png" alt="OctoBell" width="96" />
  <h1>OctoBell</h1>
  <p>A lightweight macOS menu bar app for monitoring your GitHub Actions workflow runs — in real time.</p>

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift&logoColor=white)
[![Release](https://img.shields.io/github/v/release/zigastrgar/octobell?label=latest)](https://github.com/zigastrgar/octobell/releases/latest)
![License](https://img.shields.io/github/license/zigastrgar/octobell)
![GitHub Issues](https://img.shields.io/github/issues/zigastrgar/octobell)

</div>

---

## What is OctoBell?

OctoBell lives in your macOS menu bar and keeps you informed about your GitHub Actions runs without ever leaving your current workflow. It polls your repositories on a smart dual-speed schedule — every 1/5/10 minutes for a full refresh, and every 20 seconds for any active (running/queued) jobs — so you always have an accurate, up-to-date view.

When a run completes, OctoBell sends you a native macOS notification. If it failed, you can re-trigger it directly from the notification itself.

## Features

- 🔔 **Real-time run monitoring** — watches all your GitHub Actions runs across multiple repositories
- ⚡ **Dual-speed polling** — fast 20s updates for active runs; slower adjustable full refresh interval
- 🔕 **Per-repo toggle** — disable monitoring for any repository you don't care about
- 🔄 **Re-run from notification** — trigger a failed workflow retry directly from the macOS notification banner
- 🔍 **Search & branch filter** — search runs by name or branch across all your repos
- ⌘R **Keyboard shortcut** — manual refresh anytime with `⌘R`
- 🔒 **Secure auth** — GitHub Device Flow OAuth; token stored in the macOS Keychain
- ♿ **Accessibility-first** — full VoiceOver support with descriptive labels, hints, and traits

## Screenshots

> _Coming soon._

## Requirements

- macOS 14.0 (Sonoma) or later
- A GitHub account

## Installation

### Homebrew (recommended)

OctoBell is distributed as a Homebrew cask directly from this repository. The app is signed with an Apple Developer ID and notarized by Apple.

```bash
brew install --cask zigastrgar/octobell/octobell
```

Or if you prefer to add the tap first:

```bash
brew tap zigastrgar/octobell https://github.com/zigastrgar/octobell
brew install --cask octobell
```

To update to the latest version:

```bash
brew upgrade --cask octobell
```

### Direct download

Download the latest `.dmg` from the [Releases page](https://github.com/zigastrgar/octobell/releases/latest), open it, and drag **OctoBell.app** into your Applications folder.

> [!NOTE]
> Because OctoBell is a menu bar app it won't appear in the Dock. Look for the 🔔 icon in your menu bar after launching it from Applications.

## Development

### Prerequisites

- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/zigastrgar/octobell.git
cd octobell

# 2. Generate the Xcode project
xcodegen

# 3. Open in Xcode and run
open OctoBell.xcodeproj
```

Press `⌘R` in Xcode to build and run.

## Authentication

OctoBell uses the **GitHub Device Flow** — no passwords, no personal access tokens created manually. On first launch:

1. Click **Sign In** in the menu bar popover.
2. A one-time code is copied to your clipboard and GitHub opens in your browser automatically.
3. Enter the code on GitHub, authorize OctoBell, and you're done.

The token is stored securely in the macOS Keychain under `com.zigastrgar.octobell`.

## Setup & Repository Access

OctoBell needs explicit permission to access the repositories you want to monitor. If you see a "No Repository Access" screen after signing in, follow these steps:

1.  Go to the [OctoBell GitHub App page](https://github.com/apps/octobell).
2.  Click on **Configure** (or **Install** if you haven't yet).
3.  Select the account or organization where you want to use OctoBell.
4.  Under **Repository access**, choose either:
    - **All repositories**: Grants OctoBell access to every repository in that account.
    - **Only select repositories**: Choose specific repositories you want to monitor.
5.  Click **Save**.

Once permissions are updated, OctoBell will automatically detect the new repositories during the next refresh cycle, or you can trigger a manual refresh with `⌘R`.

## Project Structure

```
Sources/
├── AppDelegate.swift          # Menu bar status item, popover, notifications
├── OctoBellApp.swift          # App entry point
├── AuthManager.swift          # GitHub Device Flow OAuth
├── GitHubClient.swift         # GitHub REST API client
├── WorkflowManager.swift      # Polling logic, state management
├── SettingsManager.swift      # User preferences (persisted to UserDefaults)
├── MetricsManager.swift       # Lightweight usage analytics
├── NotificationManager.swift  # macOS UserNotifications integration
├── KeychainHelper.swift       # Keychain read/write helpers
├── ContentView.swift          # Root SwiftUI view + shared UI components
├── Models/                    # Codable data models (GHWorkflowRun, GHRepository, …)
└── Views/
    ├── RunsTabView.swift       # Workflow runs list with search + branch filter
    ├── ReposTabView.swift      # Repository enable/disable toggles
    └── ProfileTabView.swift    # User profile + app settings
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. For new features or bug reports, open an issue using one of the provided templates.

## Privacy & Security

OctoBell is designed with privacy and security in mind:

- **Minimal Data Access**: OctoBell only fetches metadata about your workflow runs (status, name, branch, etc.). It **never** reads workflow logs, source code, or any other sensitive content.
- **Strict Permissions**: OctoBell only interacts with repositories you have explicitly granted it access to. It cannot see or access any other repositories in your GitHub account.
- **Local Storage**: Your GitHub authorization token is stored securely in the macOS Keychain. No data is ever sent to third-party servers; all communication happens directly between your machine and the GitHub API.

## License

This project is licensed under the [MIT License](LICENSE).
