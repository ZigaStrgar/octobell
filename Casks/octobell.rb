cask "octobell" do
  version "0.6.0"
  sha256 "34c91c4cf76d787ff6fc8284c839c67358c44f5db33a90e2174dad9c6e7e827c"

  url "https://github.com/zigastrgar/octobell/releases/download/v#{version}/OctoBell-#{version}.dmg"
  name "OctoBell"
  desc "macOS menu bar app for monitoring GitHub Actions workflow runs in real time"
  homepage "https://github.com/zigastrgar/octobell"

  # The app is signed with an Apple Developer ID and notarized
  depends_on macos: :sonoma

  app "OctoBell.app"

  zap trash: [
    "~/Library/Preferences/com.zigastrgar.octobell.plist",
    "~/Library/Caches/com.zigastrgar.octobell",
    "~/Library/Application Support/OctoBell",
    "~/Library/Saved Application State/com.zigastrgar.octobell.savedState",
  ]
end
