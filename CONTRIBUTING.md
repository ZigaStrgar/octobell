# Contributing to OctoBell

Thank you for taking the time to contribute! This document covers everything you need to know to get started.

## Table of contents

- [Code of conduct](#code-of-conduct)
- [Reporting bugs](#reporting-bugs)
- [Suggesting features](#suggesting-features)
- [Development setup](#development-setup)
- [Making changes](#making-changes)
- [Commit conventions](#commit-conventions)
- [Opening a pull request](#opening-a-pull-request)
- [Project-specific rules](#project-specific-rules)

---

## Code of conduct

This project follows the standard [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). Be respectful, constructive, and welcoming to everyone.

---

## Reporting bugs

Use the [Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml) issue template. Please include:

- A clear description of what went wrong
- Step-by-step reproduction instructions
- Your macOS version and OctoBell version
- Any relevant console output

---

## Suggesting features

Use the [Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml) issue template. Before submitting, search existing issues to avoid duplicates.

---

## Development setup

### Prerequisites

| Tool      | Install                                                       |
| --------- | ------------------------------------------------------------- |
| Xcode 15+ | [Mac App Store](https://apps.apple.com/app/xcode/id497799835) |
| XcodeGen  | `brew install xcodegen`                                       |

### First-time setup

```bash
git clone https://github.com/zigastrgar/octobell.git
cd octobell

# Generate the Xcode project from project.yml
xcodegen

# Open in Xcode
open OctoBell.xcodeproj
```

Press `⌘R` to build and run. The app will appear in your menu bar.

### Regenerating the project

Any time you add or remove source files, or change build settings, edit `project.yml` and re-run:

```bash
xcodegen
```

> [!IMPORTANT]
> **Never edit `.xcodeproj` directly.** All project structure changes must go through `project.yml` + `xcodegen`. Changes made directly to `.xcodeproj` will be overwritten and will break CI.

---

## Making changes

1. **Fork** the repository and create a branch from `main`:
   ```bash
   git checkout -b feat/my-new-feature
   ```
2. Make your changes, following the [project-specific rules](#project-specific-rules) below.
3. Build and test locally (`⌘R` in Xcode).
4. Commit using [conventional commits](#commit-conventions).
5. Push and [open a pull request](#opening-a-pull-request).

---

## Commit conventions

OctoBell uses [Conventional Commits](https://www.conventionalcommits.org/). This drives automatic versioning and changelog generation via [Release Please](https://github.com/googleapis/release-please).

### Format

```
<type>(<optional scope>): <short description>

[optional body]

[optional footer(s)]
```

### Types

| Type             | When to use                                 | Version bump |
| ---------------- | ------------------------------------------- | ------------ |
| `feat`           | A new feature                               | minor        |
| `fix`            | A bug fix                                   | patch        |
| `feat!` / `fix!` | Breaking change                             | major        |
| `refactor`       | Code restructuring with no behaviour change | none         |
| `docs`           | Documentation only                          | none         |
| `chore`          | Build process, dependencies, tooling        | none         |
| `style`          | Formatting, whitespace                      | none         |
| `perf`           | Performance improvement                     | none         |

### Examples

```
feat: add per-repo run count picker to repos tab
fix: prevent spinner from persisting after all runs complete
docs: add homebrew installation instructions
chore: bump xcodegen to 2.42
feat!: replace keychain service identifier — existing tokens will be invalidated
```

---

## Opening a pull request

- Fill in the PR template completely.
- Keep PRs focused — one logical change per PR.
- For UI changes, include before/after screenshots or a screen recording.
- Link the PR to any related issue (`Closes #123`).
- Ensure the app builds cleanly with no warnings introduced by your change.

A maintainer will review your PR as soon as possible. Feedback will be given as review comments; please address each one or explain your reasoning.

---

## Project-specific rules

### XcodeGen is required

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`. **Do not commit changes to `OctoBell.xcodeproj`** — the file is git-ignored for generated artefacts. Only `project.yml` should be modified, and you must run `xcodegen` afterwards.

### Accessibility

Every new interactive UI element must have appropriate SwiftUI accessibility modifiers:

```swift
.accessibilityLabel("…")
.accessibilityHint("…")
.accessibilityAddTraits(…)
```

Decorative images should be hidden with `.accessibilityHidden(true)`.

### No direct Keychain access outside `KeychainHelper`

All Keychain reads and writes must go through `KeychainHelper.swift`. Do not call `SecItemAdd` / `SecItemCopyMatching` etc. directly from other files.

### Polling logic lives in `WorkflowManager`

The dual-speed polling strategy (slow full refresh + fast active-run refresh) is implemented in `WorkflowManager.swift`. Avoid adding timer logic elsewhere.

### No debug output in production paths

Remove `print(…)` statements from code paths that run in production. Debug logging is acceptable only inside `#if DEBUG` guards.
