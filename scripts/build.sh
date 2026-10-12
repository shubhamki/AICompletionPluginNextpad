#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/WritingAssistant
xcrun clang++ -std=c++17 -fobjc-arc -fvisibility=hidden -Wall -Wextra \
  -Wno-unused-parameter -mmacosx-version-min=12.0 -arch arm64 -arch x86_64 \
  -dynamiclib -Ivendor -Isrc src/PluginMain.mm src/LocalModel.mm src/AutoSuggest.mm src/SuggestionText.mm src/CodeCompletion.mm \
  -framework Cocoa -O2 -o build/WritingAssistant/WritingAssistant.dylib
codesign --force --sign - build/WritingAssistant/WritingAssistant.dylib
cp README.md build/WritingAssistant/
mkdir -p build/WritingAssistant/licenses
cp LICENSE vendor/*LICENSE.txt build/WritingAssistant/licenses/
mkdir -p build/WritingAssistant/models
cp models/*.Modelfile build/WritingAssistant/models/
ditto -c -k --norsrc --keepParent build/WritingAssistant build/WritingAssistant.zip
echo "Built build/WritingAssistant.zip"
