# ChargePeek

A tiny macOS menu bar utility that reads iPhone and Android battery levels from the menu bar.

## Install

Install with one command:

```bash
brew install --cask q858333/iphone-battery-menu/iphone-battery-menu
```

Or tap the repository first, then install with the short cask name:

```bash
brew tap q858333/iphone-battery-menu
brew install --cask iphone-battery-menu
```

Homebrew installs the required `libimobiledevice` and `android-platform-tools` formulae with the app.

## Requirements

- `/opt/homebrew/bin/idevice_id` and `/opt/homebrew/bin/ideviceinfo` for iPhone monitoring
- `/opt/homebrew/bin/adb` for Android monitoring
- A trusted iPhone connection, or an Android device with USB debugging enabled

## Run

```bash
./run.sh
```

The menu bar item shows the selected device battery percentage and a lightning mark while charging. It refreshes every 30 seconds and sends a macOS notification once the battery reaches the configured alert level.

Use **Set Alert Level...** from the menu bar item to enter a percentage from 1 to 100. The default is 78%.

## Build a macOS App

```bash
./build-app.sh
open .build/release/ChargePeek.app
```

The app uses Homebrew device tools, so it should be run outside Codex's sandbox.
