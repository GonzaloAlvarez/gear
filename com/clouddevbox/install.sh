#!/usr/bin/env bash
#
# Install clouddevbox (cloud devbox manager, repo:
# GonzaloAlvarez/cn-cli-devbox) to ~/bin. Shared by setup-darwin /
# setup-debian / setup-linux / setup-termux. Distribution is the raw file on
# main, clouddevbox-style: publishing = pushing to main.
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

# A foreign `clouddevbox` already on PATH would win gear's `command -v`
# dispatch forever and this install would be dead code - refuse loudly instead.
existing="$(command -v clouddevbox 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/clouddevbox" ]; then
    echo "clouddevbox: a different 'clouddevbox' is already on PATH at $existing -" >&2
    echo "clouddevbox: refusing to shadow-install; remove it or rename it first" >&2
    exit 1
fi

mkdir -p "$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/GonzaloAlvarez/cn-cli-devbox/main/clouddevbox \
    -o "$HOME/bin/clouddevbox"
chmod +x "$HOME/bin/clouddevbox"
echo "clouddevbox installed: $HOME/bin/clouddevbox"

if [ "$__OSSTR" = "termux" ]; then
    echo "note: 'clouddevbox ssm' is unsupported on Termux (no aws CLI /"
    echo "session-manager-plugin on bionic); use 'clouddevbox ssh' over the"
    echo "Tailscale app's VPN."
elif ! command -v session-manager-plugin >/dev/null 2>&1; then
    echo "note: session-manager-plugin not on PATH - 'clouddevbox ssm' needs it:"
    hint_component session-manager-plugin \
        "https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html"
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "note: python3 not on PATH - clouddevbox is a python3 script"
elif ! python3 -c 'import venv' >/dev/null 2>&1; then
    echo "note: python3 venv module missing - the throwaway venv needs it:"
    echo "  sudo apt-get install python3-venv"
elif ! python3 -c 'import boto3, bullet' >/dev/null 2>&1; then
    echo "note: boto3/bullet not importable - every run builds a throwaway venv (~10-20s);"
    echo "      'python3 -m pip install --user boto3 bullet' makes runs near-instant"
fi
if [ ! -d "$HOME/.aws" ]; then
    echo "note: no ~/.aws - configure a profile first: aws configure --profile <name>"
fi
