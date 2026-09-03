#!/usr/bin/env bash
#
# Install kora (one-VM-at-a-time manager, repo: GonzaloAlvarez/kora) to
# ~/bin. Shared by setup-darwin / setup-debian / setup-linux. Distribution is
# the raw file on main, clouddevbox-style: publishing = pushing to main.
#
set -euo pipefail

KORA_VERSION="0.1.0"   # keep in sync with VERSION= in the kora repo (`gear info` greps this)

# A foreign `kora` already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v kora 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/kora" ]; then
    echo "kora: a different 'kora' is already on PATH at $existing - refusing to" >&2
    echo "kora: shadow-install; remove it or rename it first" >&2
    exit 1
fi

mkdir -p "$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/GonzaloAlvarez/kora/main/kora \
    -o "$HOME/bin/kora"
chmod +x "$HOME/bin/kora"
echo "kora installed: $HOME/bin/kora (v$KORA_VERSION)"

if [ "$(uname -s)" = "Darwin" ]; then
    command -v tart >/dev/null 2>&1 || \
        echo "note: tart not on PATH - local VMs need it: brew install cirruslabs/cli/tart cirruslabs/cli/sshpass"
    command -v qemu-system-aarch64 >/dev/null 2>&1 || \
        echo "note: qemu not on PATH - arch VMs need it: brew install qemu"
else
    command -v qemu-system-x86_64 >/dev/null 2>&1 || \
        echo "note: qemu not on PATH - local VMs need it: sudo apt-get install qemu-system-x86 genisoimage (or the amun 'qemu' plugin)"
fi
if ! command -v clouddevbox >/dev/null 2>&1; then
    echo "note: clouddevbox not on PATH - 'kora new --cloud' needs it:"
    echo "  ~/.gear/com/clouddevbox/setup-$(uname -s | tr '[:upper:]' '[:lower:]' | sed 's/darwin/darwin/;s/linux/debian/')"
fi
