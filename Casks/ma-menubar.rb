cask "ma-menubar" do
  version "1.3.3"
  sha256 "9c145f8b2e3b5ff35ee9e63f0d42aad63e7b20594ab4ff3bd4f48923c487f076"

  url "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/releases/download/v#{version}/MA-Menubar-v#{version}.dmg"
  name "MA Menubar"
  desc "Menüleisten-Client für Music Assistant"
  homepage "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar"

  app "MA Menubar.app"

  zap trash: [
    "~/Library/Preferences/org.fire-devils.MAMenubar.plist",
  ]
end
