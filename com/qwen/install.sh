#!/usr/bin/env bash
#
# Install the qwen-code CLI (@qwen-code/qwen-code) as an npm global under
# Homebrew's node. Shared by setup-darwin. Deliberately NO foreign-binary
# guard: npm's global bin (/opt/homebrew/bin) is exactly where this lands,
# so an existing binary on PATH is a previous install, not a foreign one —
# a kora-style guard would refuse forever on every machine.
#
set -euo pipefail

QWEN_VERSION="0.23.3"   # exact npm pin (`gear info` greps this)

# Keep this command's name off the brew line (gear's brew-detection regex).
brew list node >/dev/null 2>&1 || brew install node

npm install -g "@qwen-code/qwen-code@${QWEN_VERSION}"
echo "qwen installed: $(command -v qwen) (v$QWEN_VERSION)"
echo "note: local-model config is seshat-owned - install it with: seshat install llm.qwen.local"
