cask "ma-menubar" do
  version "1.2.1"
  sha256 "a2c33296197003a94020cc5f7db842b1856eae40269e023a3d4c45c0d45a8603"

  url "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/releases/download/v#{version}/MA-Menubar-v#{version}.dmg"
  name "MA Menubar"
  desc "Menüleisten-Client für Music Assistant"
  homepage "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar"

  app "MA Menubar.app"

  zap trash: [
    "~/Library/Preferences/org.fire-devils.MAMenubar.plist",
  ]
end
