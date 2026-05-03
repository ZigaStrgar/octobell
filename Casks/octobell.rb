cask "octobell" do
  version "0.5.0"
  sha256 "75794b2f4de6b7a30e27c7c2448947145cd1c76beb1e305e082954aa6ee6c4bb"

  url "https://github.com/zigastrgar/octobell/releases/download/v#{version}/OctoBell-#{version}.dmg"
  name "OctoBell"
  desc "macOS menu bar app for monitoring GitHub Actions workflow runs in real time"
  homepage "https://github.com/zigastrgar/octobell"

  # The app is signed with an Apple Developer ID and notarized
  depends_on macos: ">= :sonoma"

  app "OctoBell.app"

  zap trash: [
    "~/Library/Preferences/com.zigastrgar.octobell.plist",
    "~/Library/Caches/com.zigastrgar.octobell",
    "~/Library/Application Support/OctoBell",
    "~/Library/Saved Application State/com.zigastrgar.octobell.savedState",
  ]
end
