#!/usr/bin/env bash
#
# Download, checksum-verify, and install the latest herdr release binary
# (the terminal runtime coding agents live on, repo: herdrdev/herdr) to
# ~/bin. Shared by setup-darwin / setup-debian / setup-linux.
#
# By default this tracks the latest release as described by herdr's own
# release manifest — the same https://herdr.dev/latest.json that `herdr
# update` reads, so a gear install and a self-update always agree on what
# "latest" means. To pin an older release instead, set HERDR_VERSION to the
# release number (leading "v" optional); see the checksum caveat below.
#
# Manifest layout (it describes only the current release):
#   { "version": "<x.y.z>",
#     "assets": { "<os>-<arch>": "<download url>", ... },
#     "sha256": { "<os>-<arch>": "<64 hex chars>", ... } }
# where <os> is linux|macos and <arch> is x86_64|aarch64, and the assets are
# the plain per-platform binaries of the matching GitHub release:
#   https://github.com/herdrdev/herdr/releases/download/vX.Y.Z/herdr-<os>-<arch>
# Keep that literal URL here: `gear info` scrapes the owner/repo out of this
# script's text to look up the latest release, and it cannot see through the
# ${HERDR_REPO_SLUG} expansion used below.
#
# Deliberately not upstream's `curl https://herdr.dev/install.sh | sh`: that
# lands in ~/.local/bin, outside gear's ~/bin, where it would shadow this
# install forever (see the PATH guard below).
#
set -euo pipefail

HERDR_REPO_SLUG="${HERDR_REPO_SLUG:-herdrdev/herdr}"
HERDR_MANIFEST_URL="${HERDR_MANIFEST_URL:-https://herdr.dev/latest.json}"

fail() { echo "herdr: $*" >&2; exit 1; }

# Install per-user into ~/bin (override with HERDR_INSTALL_DIR, the same env
# var upstream's installer honors). dotfiles creates ~/bin and prepends it to
# PATH for both bash and zsh, so there is nothing else to wire up and no
# sudo anywhere in this script.
install_dir="${HERDR_INSTALL_DIR:-$HOME/bin}"
target="$install_dir/herdr"

# A foreign `herdr` already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead. The
# likely culprits are a Homebrew-managed herdr and upstream's own installer
# at ~/.local/bin/herdr.
existing="$(command -v herdr 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$target" ]; then
    echo "herdr: a different 'herdr' is already on PATH at $existing - refusing to" >&2
    echo "herdr: shadow-install; remove it or rename it first" >&2
    exit 1
fi

# Upstream ships no Android/bionic artifact and refuses Termux outright,
# which is why com/herdr has no setup-termux: gear has no termux->linux
# fallback by design (see the repo README).
[ -z "${TERMUX_VERSION:-}" ] || \
    fail "Termux is unsupported by herdr's release binaries - ssh to a supported host instead"

case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="macos" ;;
    *)      fail "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
    x86_64|amd64)   arch="x86_64" ;;
    aarch64|arm64)  arch="aarch64" ;;
    *)              fail "unsupported arch: $(uname -m)" ;;
esac

platform="${os}-${arch}"

stage="$(mktemp -d "${TMPDIR:-/tmp}/herdr.XXXXXX")"
trap 'rm -rf "$stage"' EXIT

# Pull "<key>": "<value>" out of one top-level manifest object.
#
# The manifest is read to a FILE and awk'd from there rather than piped out
# of curl: under `set -o pipefail`, a reader that stops early closes the pipe
# and kills the writer with SIGPIPE, failing the whole install with status
# 141. This manifest inlines every release note and runs ~180 KB, far past
# the pipe-buffer size where that bites — the same trap that broke
# com/kauket on its first multi-asset release. For the same reason the awk
# below never `exit`s early; it reads to EOF and prints in END.
manifest_get() {   # $1=object  $2=key
    awk -v obj="\"$1\"" -v key="\"$2\"" '
        $0 ~ "^[[:space:]]*" obj "[[:space:]]*:" { in_obj = 1; next }
        in_obj && /^[[:space:]]*}/              { in_obj = 0 }
        in_obj && !found && index($0, key) {
            sub(/^.*:[[:space:]]*"/, ""); sub(/".*$/, "")
            value = $0; found = 1
        }
        END { if (found) print value }
    ' "$stage/latest.json"
}

version="${HERDR_VERSION:-}"
if [ -n "$version" ]; then
    # An explicit pin. The manifest only ever describes the current release,
    # so there is no published sha256 to check an older asset against and
    # the download goes in unverified (it says so below). Prefer the default
    # latest-tracking path.
    version="${version#v}"
    url="https://github.com/${HERDR_REPO_SLUG}/releases/download/v${version}/herdr-${platform}"
    sha256=""
else
    curl -fsSL --retry 3 --connect-timeout 10 --max-time 30 \
        "$HERDR_MANIFEST_URL" -o "$stage/latest.json" \
        || fail "could not fetch the release manifest at $HERDR_MANIFEST_URL"
    version="$(awk -F'"' '/^[[:space:]]*"version"[[:space:]]*:/ && !seen { print $4; seen = 1 }' \
        "$stage/latest.json")"
    url="$(manifest_get assets "$platform")"
    sha256="$(manifest_get sha256 "$platform")"
    [ -n "$version" ] || fail "no version in the release manifest"
    [ -n "$url" ]     || fail "the release manifest has no binary for $platform"
    [ "${#sha256}" -eq 64 ] || fail "the release manifest has no sha256 for $platform"
fi

curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 "$url" -o "$stage/herdr" \
    || fail "download of $url failed"

if [ -n "$sha256" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$stage/herdr" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        actual="$(shasum -a 256 "$stage/herdr" | awk '{print $1}')"
    else
        fail "sha256 verification needs sha256sum or shasum"
    fi
    [ "$actual" = "$sha256" ] || \
        fail "checksum mismatch for herdr-$platform (expected $sha256, got $actual)"
else
    echo "herdr: pinned v$version - no published sha256 for an old release, installed unverified" >&2
fi

mkdir -p "$install_dir"
install -m 0755 "$stage/herdr" "$target"

echo "herdr installed: $target (v$version)"

# Two ways up, deliberately not in conflict: `herdr update` reads the same
# manifest and rewrites the binary in place, so it and `gear update herdr`
# both end at $target and neither can leave a second herdr on PATH.
echo "note: 'herdr update' self-updates in place; 'gear update herdr' reinstalls from here"
# The background server keeps running the binary it started from, so a fresh
# install does not take effect in sessions already attached to it.
echo "note: restart the server to pick up a new version ('herdr server stop', then 'herdr')"
