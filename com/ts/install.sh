#!/usr/bin/env bash
#
# Install the ts tailnet client to ~/bin. Shared by setup-darwin /
# setup-debian / setup-linux. On macOS additionally compiles the menu-bar
# indicator, best-effort: no swiftc (or a failed build) just prints a
# warning — ts degrades gracefully without the dot.
#
set -euo pipefail

TS_VERSION="1.0.0"   # keep in sync with VERSION= in com/ts/ts (`gear info` greps this)

__DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$HOME/bin"
cp "$__DIR/ts" "$HOME/bin/ts"
chmod +x "$HOME/bin/ts"

if [ "$(uname -s)" = "Darwin" ]; then
    if command -v swiftc >/dev/null 2>&1; then
        swiftc -O -o "$HOME/bin/ts-indicator" "$__DIR/ts-indicator.swift" \
            || echo "ts: indicator build failed — ts works without the menu-bar dot" >&2
    else
        echo "ts: swiftc not found (install Xcode CLT) — skipping menu-bar indicator" >&2
    fi
fi

echo "ts installed: $HOME/bin/ts (v$TS_VERSION)"
