#!/usr/bin/env bash
#
# Download, checksum-verify, and install the pinned kauket release binary.
# Shared by setup-darwin / setup-debian / setup-linux. This is the single
# source of truth for the pinned kauket version.
#
# Mirrors the release-artifact layout published by kauket's goreleaser:
#   https://github.com/GonzaloAlvarez/kauket/releases/download/vX.Y.Z/
#     kauket_X.Y.Z_<os>_<arch>.tar.gz
#     checksums.txt   (lines: "<sha256>  <filename>")
#
set -euo pipefail

KAUKET_VERSION="${KAUKET_VERSION:-1.0.0}"
KAUKET_REPO_SLUG="${KAUKET_REPO_SLUG:-GonzaloAlvarez/kauket}"

fail() { echo "kauket: $*" >&2; exit 1; }

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

if [ "$os" = "darwin" ] && [ "$arch" = "arm64" ]; then
    install_dir="/opt/homebrew/bin"
else
    install_dir="/usr/local/bin"
fi
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

# kauket keeps its identities/config here; ensure it exists at 0700.
mkdir -p "$HOME/.config/kauket"
chmod 0700 "$HOME/.config/kauket"

echo "kauket installed: $("$target" version 2>/dev/null || echo "$target")"
