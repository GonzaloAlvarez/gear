#!/usr/bin/env bash
#
# Install awsdashboard (federated AWS console sign-in URL, repo:
# GonzaloAlvarez/awsutils) to ~/bin. Shared by setup-darwin / setup-debian /
# setup-linux. Distribution is the raw file on main, clouddevbox-style:
# publishing = pushing to main.
#
set -euo pipefail

AWSDASHBOARD_VERSION="0.1.0"   # keep in sync with VERSION= in the awsutils repo (`gear info` greps this)

# A foreign `awsdashboard` already on PATH would win gear's `command -v`
# dispatch forever and this install would be dead code - refuse loudly instead.
existing="$(command -v awsdashboard 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/awsdashboard" ]; then
    echo "awsdashboard: a different 'awsdashboard' is already on PATH at $existing - refusing" >&2
    echo "awsdashboard: to shadow-install; remove it or rename it first" >&2
    exit 1
fi

mkdir -p "$HOME/bin"
curl -fsSL https://raw.githubusercontent.com/GonzaloAlvarez/awsutils/main/awsdashboard \
    -o "$HOME/bin/awsdashboard"
chmod +x "$HOME/bin/awsdashboard"
echo "awsdashboard installed: $HOME/bin/awsdashboard (v$AWSDASHBOARD_VERSION)"

if ! command -v python3 >/dev/null 2>&1; then
    echo "note: python3 not on PATH - awsdashboard is a python3 script"
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
if [ "$(uname -s)" = "Darwin" ]; then
    command -v open >/dev/null 2>&1 || echo "note: no 'open' - '--open' needs a browser handler"
else
    command -v xdg-open >/dev/null 2>&1 || \
        echo "note: xdg-open not on PATH - '--open' needs a browser handler (xdg-utils)"
fi
echo "note: all awsdashboard calls are free (sts, iam:ListRoles, signin.aws.amazon.com)"
