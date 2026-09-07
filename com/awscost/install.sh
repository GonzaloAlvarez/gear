#!/usr/bin/env bash
#
# Install awscost (monthly AWS spend by service, repo:
# GonzaloAlvarez/awsutils) to ~/bin. Shared by setup-darwin / setup-debian /
# setup-linux. Distribution is the raw file on main, clouddevbox-style:
# publishing = pushing to main.
#
set -euo pipefail

AWSCOST_VERSION="1.1.0"   # keep in sync with VERSION= in the awsutils repo (`gear info` greps this)

# A foreign `awscost` already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v awscost 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/awscost" ]; then
    echo "awscost: a different 'awscost' is already on PATH at $existing - refusing to" >&2
    echo "awscost: shadow-install; remove it or rename it first" >&2
    exit 1
fi

mkdir -p "$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/GonzaloAlvarez/awsutils/main/awscost \
    -o "$HOME/bin/awscost"
chmod +x "$HOME/bin/awscost"
echo "awscost installed: $HOME/bin/awscost (v$AWSCOST_VERSION)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "note: python3 not on PATH - awscost is a python3 script"
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
echo "note: each awscost run makes one Cost Explorer request (~\$0.01)"
