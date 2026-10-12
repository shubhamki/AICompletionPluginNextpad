#!/bin/bash
# Manual isolated setup UI check. Requires a built plugin, never opens user files.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/SetupCheck.app/Contents/MacOS
cp tests/setup-ui.plist build/SetupCheck.app/Contents/Info.plist
xcrun clang++ -std=c++17 -fobjc-arc -Ivendor tests/setup_ui.mm \
  -framework Cocoa -o build/SetupCheck.app/Contents/MacOS/SetupCheck
test_config=$(mktemp -d "${TMPDIR:-/tmp}/nextpad-setup-check.XXXXXX")
build/SetupCheck.app/Contents/MacOS/SetupCheck "$PWD/build/WritingAssistant/WritingAssistant.dylib" "$test_config"
