#!/usr/bin/env bash
#
# Install the qwen-code CLI (@qwen-code/qwen-code) as an npm global. Shared
# by setup-darwin (brew node) and setup-linux (any node: system, mise,
# asdf). Deliberately NO foreign-binary guard: npm's global bin is exactly
# where this lands, so an existing binary on PATH is a previous install,
# not a foreign one — a kora-style guard would refuse forever.
#
set -euo pipefail

QWEN_VERSION="0.23.3"   # exact npm pin (`gear info` greps this)

if [ "$(uname -s)" = "Darwin" ]; then
    # Keep this command's name off the brew line (gear's brew-detection regex).
    brew list node >/dev/null 2>&1 || brew install node
    npm install -g "@qwen-code/qwen-code@${QWEN_VERSION}"
else
    if ! command -v npm >/dev/null 2>&1; then
        echo "qwen: npm not found - install node first (amun development, mise," >&2
        echo "qwen: or your package manager), then re-run" >&2
        exit 1
    fi
    # Sudo-free house rule: system npm prefixes like /usr are root-owned, so
    # install the global into ~/.local instead (on PATH via the dotfiles).
    prefix="$(npm config get prefix 2>/dev/null || echo /usr)"
    if [ ! -w "$prefix" ]; then
        export npm_config_prefix="$HOME/.local"
    fi
    npm install -g "@qwen-code/qwen-code@${QWEN_VERSION}"
    # Tool-version managers need a reshim before the new bin resolves.
    if ! command -v qwen >/dev/null 2>&1; then
        if command -v mise >/dev/null 2>&1; then mise reshim >/dev/null 2>&1 || true; fi
        if command -v asdf >/dev/null 2>&1; then asdf reshim nodejs >/dev/null 2>&1 || true; fi
    fi
fi

if ! command -v qwen >/dev/null 2>&1; then
    echo "qwen: installed but not resolving on PATH - check npm prefix bin dir" >&2
    exit 1
fi
echo "qwen installed: $(command -v qwen) (v$QWEN_VERSION)"
echo "note: local-model config is seshat-owned - install it with: seshat install llm.qwen.local"
