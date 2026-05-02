cask "octobell" do
  version "0.2.0"
  sha256 "77c04c6a95b6ad20384cf688f44d4f00571ce7f63099f816b967bd04990c4dd4"

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
