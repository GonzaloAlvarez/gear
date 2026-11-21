#!/usr/bin/env bash
#
# Install OpenCode (https://opencode.ai, repo anomalyco/opencode) — the
# open-source terminal coding agent used against the homelab LLM router
# (dotfiles bundle llm.client renders ~/.config/opencode/opencode.json).
# Shared by setup-darwin, setup-debian and setup-linux.
#
# Pinned release binary from GitHub, sha256-verified per platform, installed
# to ~/bin (gear's house location, ahead of brew on PATH). Deliberately not
# Homebrew's formula (it lags and lands outside ~/bin) and
# not `npm i -g opencode-ai` (needs node; the npm "latest" tag trailed the
# 2.x line by a major version at pin time). OpenCode's self-update is turned
# off by the bundle config (autoupdate=false) so gear owns the version.
# Bump recipe:
#   tag=v2.3.2
#   gh api repos/anomalyco/opencode/releases/tags/$tag \
#     --jq '.assets[]|select(.name|test("^opencode-(darwin-arm64.zip|linux-(x64|arm64).tar.gz)$"))|[.name,.digest]|@tsv'
#
set -euo pipefail

OPENCODE_VERSION="2.3.2"   # `gear info` greps the FIRST *VERSION= line — keep it this one
OPENCODE_REPO_SLUG="anomalyco/opencode"
# Keep this literal URL form here: `gear info` scrapes owner/repo from the text.
#   https://github.com/anomalyco/opencode/releases/download/v<version>/opencode-<platform>.<zip|tar.gz>
SHA256_DARWIN_ARM64="31ab5a06a29edc7e49b895f35c2b64ebfe7c7f0437b0f2581b006efcd79fee1a"   # opencode-darwin-arm64.zip
SHA256_LINUX_X64="563b5d663637226b6e3bb4bb6803281bc39b0d2cd88db06d674b6420aab009b0"      # opencode-linux-x64.tar.gz
SHA256_LINUX_ARM64="9d10185acdb72336e086e699ca363a6065f410fd3c1caed0dc8046e95ac06ccb"    # opencode-linux-arm64.tar.gz

fail() { echo "opencode: $*" >&2; exit 1; }

install_dir="${OPENCODE_INSTALL_DIR:-$HOME/bin}"
target="$install_dir/opencode"

# A foreign `opencode` already on PATH (brew, npm global, upstream's curl
# installer in ~/.opencode/bin) would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v opencode 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$target" ]; then
    echo "opencode: a different 'opencode' is already on PATH at $existing - refusing to" >&2
    echo "opencode: shadow-install; remove it or rename it first" >&2
    exit 1
fi

[ -z "${TERMUX_VERSION:-}" ] || fail "no Termux build of OpenCode - ssh to a supported host instead"

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)              platform="darwin-arm64"; ext="zip";    sha256="$SHA256_DARWIN_ARM64" ;;
    Linux-x86_64|Linux-amd64)  platform="linux-x64";    ext="tar.gz"; sha256="$SHA256_LINUX_X64" ;;
    Linux-aarch64|Linux-arm64) platform="linux-arm64";  ext="tar.gz"; sha256="$SHA256_LINUX_ARM64" ;;
    *) fail "no pinned OpenCode build for $(uname -s)/$(uname -m) (Intel Macs: use the Homebrew formula by hand)" ;;
esac

asset="opencode-${platform}.${ext}"
url="https://github.com/${OPENCODE_REPO_SLUG}/releases/download/v${OPENCODE_VERSION}/${asset}"

stage="$(mktemp -d "${TMPDIR:-/tmp}/opencode.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

echo "opencode: fetching v$OPENCODE_VERSION ($platform)"
curl -fsSL --retry 3 --connect-timeout 10 --max-time 600 "$url" -o "$stage/$asset" \
    || fail "download of $url failed"

if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$stage/$asset" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$stage/$asset" | awk '{print $1}')"
else
    fail "sha256 verification needs sha256sum or shasum"
fi
[ "$actual" = "$sha256" ] || fail "checksum mismatch for $asset (expected $sha256, got $actual)"

# Both archives hold the single `opencode` binary at the top level.
mkdir -p "$stage/x"
case "$ext" in
    zip)
        if command -v unzip >/dev/null 2>&1; then
            unzip -q "$stage/$asset" -d "$stage/x"
        else
            python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$stage/$asset" "$stage/x"
        fi ;;
    tar.gz) tar -xzf "$stage/$asset" -C "$stage/x" ;;
esac
[ -f "$stage/x/opencode" ] || fail "archive layout changed - no top-level opencode binary in $asset"

mkdir -p "$install_dir"
install -m 0755 "$stage/x/opencode" "$target"

"$target" --version >/dev/null 2>&1 || fail "installed binary does not run: $target"
echo "opencode installed: $target ($("$target" --version 2>/dev/null))"
echo "note: config is seshat-owned - install it with: seshat install llm.client"
