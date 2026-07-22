#!/usr/bin/env bash
#
# Install the AWS Session Manager plugin (a self-contained Go binary) into
# ~/bin from AWS's official distribution:
#   https://s3.amazonaws.com/session-manager-downloads/plugin/latest/...
# No sudo, no package manager: the binary is extracted from the official
# bundle (macOS) or .deb (Linux) and dropped on PATH, where the aws CLI
# discovers it for `aws ssm start-session`.
#
set -euo pipefail

fail() { echo "session-manager-plugin: $*" >&2; exit 1; }

BASE="https://s3.amazonaws.com/session-manager-downloads/plugin/latest"
mkdir -p "$HOME/bin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

case "$(uname -s)" in
    Darwin)
        case "$(uname -m)" in
            arm64)  variant="mac_arm64" ;;
            x86_64) variant="mac" ;;
            *)      fail "unsupported macOS arch: $(uname -m)" ;;
        esac
        curl -fsSL -o "$tmp/bundle.zip" "${BASE}/${variant}/sessionmanager-bundle.zip"
        unzip -q "$tmp/bundle.zip" -d "$tmp"
        install -m 0755 "$tmp/sessionmanager-bundle/bin/session-manager-plugin" \
            "$HOME/bin/session-manager-plugin"
        ;;
    Linux)
        case "$(uname -m)" in
            aarch64|arm64) variant="ubuntu_arm64" ;;
            x86_64|amd64)  variant="ubuntu_64bit" ;;
            *)             fail "unsupported Linux arch: $(uname -m)" ;;
        esac
        curl -fsSL -o "$tmp/smp.deb" "${BASE}/${variant}/session-manager-plugin.deb"
        dpkg-deb -x "$tmp/smp.deb" "$tmp/x"
        install -m 0755 "$tmp/x/usr/local/sessionmanagerplugin/bin/session-manager-plugin" \
            "$HOME/bin/session-manager-plugin"
        ;;
    *)
        fail "unsupported OS: $(uname -s)"
        ;;
esac

"$HOME/bin/session-manager-plugin" --version
