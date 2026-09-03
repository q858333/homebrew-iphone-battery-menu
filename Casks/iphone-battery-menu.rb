cask "iphone-battery-menu" do
  version "1.0.1"
  sha256 "19c20ffb1545e73e7616d7c715d04c4475a88747a8bf2d756f3ff440923c1b1d"

  url "https://github.com/q858333/homebrew-iphone-battery-menu/releases/download/v#{version}/iPhoneBatteryMenu.zip",
      verified: "github.com/q858333/homebrew-iphone-battery-menu/"
  name "ChargePeek"
  desc "macOS menu bar utility for monitoring iPhone and Android battery levels"
  homepage "https://github.com/q858333/homebrew-iphone-battery-menu"

  depends_on macos: :ventura
  depends_on formula: "libimobiledevice"
  depends_on formula: "android-platform-tools"

  app "ChargePeek.app"

  zap trash: [
    "~/Library/Preferences/local.ChargePeek.plist",
    "~/Library/Preferences/local.iPhoneBatteryMenu.plist",
  ]
end
