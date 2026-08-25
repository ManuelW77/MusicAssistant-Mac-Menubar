cask "ma-menubar" do
  version "1.5.1"
  sha256 "2836bafb0286fc787a2ac86f94b86dadcaffea01b6c46969a97c1fbd21ddd531"

  url "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/releases/download/v#{version}/MA-Menubar-v#{version}.dmg"
  name "MA Menubar"
  desc "Menüleisten-Client für Music Assistant"
  homepage "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar"

  app "MA Menubar.app"

  zap trash: [
    "~/Library/Preferences/org.fire-devils.MAMenubar.plist",
  ]
end
