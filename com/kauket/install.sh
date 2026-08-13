#!/usr/bin/env bash
#
# Download, checksum-verify, and install the latest kauket release binary.
# Shared by setup-darwin / setup-debian / setup-linux.
#
# By default this tracks the latest GitHub release. To pin a specific
# version instead, set the KAUKET_VERSION environment variable to the
# desired release number (without the leading "v").
#
# Mirrors the release-artifact layout published by kauket's goreleaser:
#   https://github.com/GonzaloAlvarez/kauket/releases/download/vX.Y.Z/
#     kauket_X.Y.Z_<os>_<arch>.tar.gz
#     checksums.txt   (lines: "<sha256>  <filename>")
#
set -euo pipefail

KAUKET_REPO_SLUG="${KAUKET_REPO_SLUG:-GonzaloAlvarez/kauket}"

fail() { echo "kauket: $*" >&2; exit 1; }

# Resolve the latest release tag from the GitHub API (strips the leading "v").
# Deliberately pipe-free: under `set -o pipefail`, `curl | grep -m1` dies with
# curl exit 23 (SIGPIPE) once the release JSON outgrows the pipe buffer —
# grep closes the pipe after the first match while curl is still writing.
# Bit us on kauket v2.0.0 (5 assets + changelog pushed the body past the
# threshold); a bash regex on the captured body has no pipe to break.
resolve_latest() {
    local json
    json="$(curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${KAUKET_REPO_SLUG}/releases/latest")" || return 1
    if [[ "$json" =~ \"tag_name\"[[:space:]]*:[[:space:]]*\"v?([^\"]+)\" ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
    fi
}

# Honor an explicit pin, otherwise track the latest release.
KAUKET_VERSION="${KAUKET_VERSION:-$(resolve_latest)}"
[ -n "$KAUKET_VERSION" ] || fail "could not determine latest kauket version"

case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="darwin" ;;
    *)      fail "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
    x86_64|amd64)   arch="amd64" ;;
    aarch64|arm64)  arch="arm64" ;;
    *)              fail "unsupported arch: $(uname -m)" ;;
esac

# Install per-user into ~/bin (override with KAUKET_INSTALL_DIR). This keeps
# kauket out of brew-owned prefixes and avoids needing sudo.
install_dir="${KAUKET_INSTALL_DIR:-$HOME/bin}"
mkdir -p "$install_dir" 2>/dev/null || true
target="$install_dir/kauket"

tarball="kauket_${KAUKET_VERSION}_${os}_${arch}.tar.gz"
base="https://github.com/${KAUKET_REPO_SLUG}/releases/download/v${KAUKET_VERSION}"

# Use sudo only when the install dir isn't user-writable.
if [ -d "$install_dir" ] && [ -w "$install_dir" ]; then
    SUDO=""
else
    SUDO="sudo"
fi

stage="$(mktemp -d "${TMPDIR:-/tmp}/kauket.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
cd "$stage"

curl -fsSL "$base/checksums.txt" -o checksums.txt || fail "download of checksums.txt failed"
curl -fsSL "$base/$tarball"      -o "$tarball"    || fail "download of $tarball failed"

expected="$(grep " ${tarball}$" checksums.txt | awk '{print $1}')"
[ "${#expected}" -eq 64 ] || fail "could not find sha256 for $tarball in checksums.txt"

if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tarball" | awk '{print $1}')"
else
    actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
fi
[ "$actual" = "$expected" ] || fail "checksum mismatch for $tarball (expected $expected, got $actual)"

tar -xzf "$tarball"
[ -f kauket ] || fail "kauket binary not found in $tarball"
chmod 0755 kauket

$SUDO mkdir -p "$install_dir"
$SUDO install -m 0755 kauket "$target"

# Don't pre-create the config home: kauket's EnsureHome() makes it 0700 at the
# OS-default location on first use (macOS: ~/Library/Application Support/kauket;
# Linux: ~/.config/kauket), or wherever KAUKET_HOME points. Hardcoding
# ~/.config/kauket here created a non-default stray dir on macOS.

echo "kauket installed: $("$target" version 2>/dev/null || echo "$target")"
