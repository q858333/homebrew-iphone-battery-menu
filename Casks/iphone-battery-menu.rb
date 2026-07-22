cask "iphone-battery-menu" do
  version "1.0.0"
  sha256 "d186cfb7de415427fa9d5b311c3772b004c3749bdd5144df6d7702b05cccf517"

  url "https://github.com/q858333/iPhoneBatteryMenu/releases/download/v#{version}/iPhoneBatteryMenu.zip",
      verified: "github.com/q858333/iPhoneBatteryMenu/"
  name "iPhoneBatteryMenu"
  desc "macOS menu bar utility for monitoring iPhone battery level"
  homepage "https://github.com/q858333/iPhoneBatteryMenu"

  depends_on macos: :ventura
  depends_on formula: "libimobiledevice"

  app "iPhoneBatteryMenu.app"

  zap trash: [
    "~/Library/Preferences/local.iPhoneBatteryMenu.plist",
  ]
end
