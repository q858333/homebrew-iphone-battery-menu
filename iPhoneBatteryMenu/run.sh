#!/usr/bin/env zsh
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p .build
swiftc -parse-as-library Sources/iPhoneBatteryMenu/main.swift -o .build/ChargePeek -framework AppKit
exec .build/ChargePeek
