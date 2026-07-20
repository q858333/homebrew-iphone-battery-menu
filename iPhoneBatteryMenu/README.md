# iPhoneBatteryMenu

A tiny macOS menu bar utility that reads an iPhone battery level by calling Homebrew's `libimobiledevice` tools.

## Requirements

- `/opt/homebrew/bin/idevice_id`
- `/opt/homebrew/bin/ideviceinfo`
- A trusted iPhone connection

## Run

```bash
./run.sh
```

The menu bar item shows the selected device battery percentage and a lightning mark while charging. It refreshes every 30 seconds and sends a macOS notification once the battery reaches the configured alert level.

Use **Set Alert Level...** from the menu bar item to enter a percentage from 1 to 100. The default is 78%.

## Build a macOS App

```bash
./build-app.sh
open .build/release/iPhoneBatteryMenu.app
```

The app uses `/opt/homebrew/bin/idevice_id` and `/opt/homebrew/bin/ideviceinfo`, so it should be run outside Codex's sandbox.
