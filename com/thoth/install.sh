#!/usr/bin/env bash
#
# Install thoth (bulk-clone the repo fleet by dev-* topic, repo:
# GonzaloAlvarez/thoth) to ~/bin. Shared by setup-darwin / setup-debian /
# setup-linux. Distribution is the raw file on main, clouddevbox-style:
# publishing = pushing to main.
#
set -euo pipefail

__DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# gear's own osstr taxonomy (see ~/.gear/run): termux / darwin / debian /
# linux, where "linux" is every non-Debian Linux (Arch, Fedora, Alpine, ...).
if [ -n "${TERMUX_VERSION:-}" ]; then __OSSTR=termux
elif [ "$(uname -s)" = "Darwin" ]; then __OSSTR=darwin
elif [ -f /etc/debian_version ]; then __OSSTR=debian
else __OSSTR=linux
fi

# Point at a sibling gear component only when it supports this platform: a
# hint naming a setup script that does not exist is worse than no hint.
hint_component() {   # $1=component  $2=fallback advice
    if [ -x "$__DIR/../$1/setup-$__OSSTR" ]; then
        echo "  ~/.gear/com/$1/setup-$__OSSTR"
    else
        echo "  $2"
    fi
}

# A foreign `thoth` already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v thoth 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/thoth" ]; then
    echo "thoth: a different 'thoth' is already on PATH at $existing - refusing to" >&2
    echo "thoth: shadow-install; remove it or rename it first" >&2
    exit 1
fi

mkdir -p "$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/GonzaloAlvarez/thoth/main/thoth \
    -o "$HOME/bin/thoth"
chmod +x "$HOME/bin/thoth"
echo "thoth installed: $HOME/bin/thoth"

if ! command -v gh >/dev/null 2>&1; then
    echo "note: gh not on PATH - thoth needs it:"
    hint_component gh "install the GitHub CLI: https://cli.github.com"
elif ! gh auth status >/dev/null 2>&1; then
    echo "note: gh is not authenticated - thoth needs it: gh auth login"
fi
if ! command -v git >/dev/null 2>&1; then
    echo "note: git not on PATH - thoth clones with it"
fi
