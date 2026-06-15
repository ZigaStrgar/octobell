cask "octobell" do
  version "0.5.2"
  sha256 "bbabd49788339dd1dd887f03bbed0521a23486450fcfe45b0f33bbed2253752a"

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
