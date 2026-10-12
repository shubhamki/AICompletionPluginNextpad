#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Wno-unused-parameter \
  -Ivendor -Isrc tests/core_tests.mm src/LocalModel.mm src/SuggestionText.mm src/CodeCompletion.mm -framework Foundation -o build/core_tests
build/core_tests "$@"
if [[ -f build/WritingAssistant/WritingAssistant.dylib ]]; then
  xcrun clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Ivendor \
    tests/abi_tests.mm -framework Foundation -o build/abi_tests
  build/abi_tests "$PWD/build/WritingAssistant/WritingAssistant.dylib"
fi
