cask "ma-menubar" do
  version "1.2.2"
  sha256 "34c82b0097af70d7720b51d578c3737c12ecb3213bf52411f72c2f185b0b1f58"

  url "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/releases/download/v#{version}/MA-Menubar-v#{version}.dmg"
  name "MA Menubar"
  desc "Menüleisten-Client für Music Assistant"
  homepage "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar"

  app "MA Menubar.app"

  zap trash: [
    "~/Library/Preferences/org.fire-devils.MAMenubar.plist",
  ]
end
