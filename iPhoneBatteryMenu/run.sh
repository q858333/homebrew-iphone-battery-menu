#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p .build
swiftc -parse-as-library Sources/iPhoneBatteryMenu/main.swift -o .build/iPhoneBatteryMenu -framework AppKit
exec .build/iPhoneBatteryMenu
