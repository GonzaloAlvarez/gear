#!/usr/bin/env bash
#
# Install localllm (on-demand llama.cpp server wrapper) to ~/bin and ensure
# the llama.cpp runtime (prebuilt Metal llama-server) is present via
# Homebrew. Shared by setup-darwin. Model downloads happen at RUNTIME
# (`localllm pull`/`serve`), never here — setup stays fast and gear's
# output-swallowing dispatch never hides a 22 GB download.
#
set -euo pipefail

LOCALLLM_VERSION="1.1.0"   # keep in sync with VERSION= in com/localllm/localllm (`gear info` greps this)

# A foreign binary already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v localllm 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/localllm" ]; then
    echo "localllm: a different binary is already on PATH at $existing - refusing to" >&2
    echo "localllm: shadow-install; remove it or rename it first" >&2
    exit 1
fi

# Runtime dependency (keep this command's name off the brew line — gear's
# available_version brew-detection regex keys on it).
brew list llama.cpp >/dev/null 2>&1 || brew install llama.cpp

__DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p "$HOME/bin"
cp "$__DIR/localllm" "$HOME/bin/localllm"
chmod +x "$HOME/bin/localllm"
echo "localllm installed: $HOME/bin/localllm (v$LOCALLLM_VERSION)"
echo "note: config is seshat-owned - install it with: seshat install localllm.server"
