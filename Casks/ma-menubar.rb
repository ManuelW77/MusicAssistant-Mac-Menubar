cask "ma-menubar" do
  version "1.4.0"
  sha256 "a2d12821946d8d3c12b707ca889b8ebba884ea3eafa64d2247746e6e3372b356"

  url "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar/releases/download/v#{version}/MA-Menubar-v#{version}.dmg"
  name "MA Menubar"
  desc "Menüleisten-Client für Music Assistant"
  homepage "https://github.com/ManuelW77/MusicAssistant-Mac-Menubar"

  app "MA Menubar.app"

  zap trash: [
    "~/Library/Preferences/org.fire-devils.MAMenubar.plist",
  ]
end
