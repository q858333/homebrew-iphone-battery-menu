cask "iphone-battery-menu" do
  version "1.0.2"
  sha256 "8fb595d5287a9f7215fbc49a969147529cf6f18dfa958f735866991baaab60fb"

  url "https://github.com/q858333/homebrew-iphone-battery-menu/releases/download/v#{version}/iPhoneBatteryMenu.zip",
      verified: "github.com/q858333/homebrew-iphone-battery-menu/"
  name "ChargePeek"
  desc "macOS menu bar utility for monitoring iPhone and Android battery levels"
  homepage "https://github.com/q858333/homebrew-iphone-battery-menu"

  depends_on macos: :ventura
  depends_on formula: "libimobiledevice"
  depends_on cask: "android-platform-tools"

  app "ChargePeek.app"

  zap trash: [
    "~/Library/Preferences/local.ChargePeek.plist",
    "~/Library/Preferences/local.iPhoneBatteryMenu.plist",
  ]
end
