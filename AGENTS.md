# OctoBell Agent Instructions

This file contains non-discoverable technical constraints and workflow requirements for agents.

## Project Management & Build

- **XcodeGen Requirement:** This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen). Do **NOT** modify the `.xcodeproj` file directly. Any changes to the project structure (adding/removing files, changing settings, adding dependencies) must be made in `project.yml`. After making changes, run `xcodegen` to update the Xcode project.
- **Menu Bar App:** The app is configured as a menu bar app (`LSUIElement: true` in `Info.plist`). It does not have a standard application window by default.

## API & Authentication

- **GitHub API Version:** The `GitHubClient` explicitly uses the `2026-03-10` version of the GitHub API via the `X-GitHub-Api-Version` header. This is a future-dated version used for experimental features or specific API behavior.
- **GitHub Device Flow:** Authentication uses the GitHub Device Flow. The `clientId` in `AuthManager.swift` is a hardcoded value specifically for this application's OAuth flow.
- **Keychain Storage:** Tokens are stored in the macOS Keychain under the service `com.zigastrgar.octobell` and account `OctoBell`.
- **Polling Strategy:** The app uses a dual-speed polling strategy in `WorkflowManager.swift`:
  - A "slow" refresh every 60 seconds for all workflows.
  - A "fast" refresh every 20 seconds specifically for active (running/queued) workflows to provide responsive feedback without hitting rate limits.

## Non-discoverable Commands

- **XcodeGen:** `xcodegen` (updates the `.xcodeproj` from `project.yml`).
