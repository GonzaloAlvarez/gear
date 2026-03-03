# kepr Installation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add kepr binary installation to gear with support for darwin, debian, and linux platforms.

**Architecture:** Follow gear's existing pattern with setup/remove scripts per platform. Each setup script detects architecture, fetches latest release from GitHub API, downloads appropriate tarball, and installs to $HOME/bin/kepr.

**Tech Stack:** Bash scripts, GitHub API, curl, tar

---

## Task 1: Create kepr Directory Structure

**Files:**
- Create: `/Users/galvarez/dev/gear/com/kepr/` (directory)

**Step 1: Create directory**

```bash
mkdir -p /Users/galvarez/dev/gear/com/kepr
```

**Step 2: Verify directory exists**

```bash
ls -la /Users/galvarez/dev/gear/com/kepr
```

Expected: Directory exists and is empty

---

## Task 2: Create Darwin (macOS) Setup Script

**Files:**
- Create: `/Users/galvarez/dev/gear/com/kepr/setup-darwin`

**Step 1: Write the setup script**

```bash
#!/usr/bin/env bash

export temp_path=$(mktemp -d)

function cleanup {
    rm -Rf "${temp_path}"
    set +e
}

set -e
trap cleanup EXIT

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
fi
# arm64 stays as arm64

# Fetch latest release version from GitHub API
VERSION=$(curl -s https://api.github.com/repos/gonzaloalvarez/kepr/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "Failed to fetch latest version"
    exit 1
fi

# Download the binary
DOWNLOAD_URL="https://github.com/GonzaloAlvarez/kepr/releases/download/${VERSION}/kepr-${VERSION}-darwin-${ARCH}.tar.gz"

pushd . > /dev/null
cd "${temp_path}"

curl -sL "${DOWNLOAD_URL}" -o kepr.tar.gz

if [ ! -f kepr.tar.gz ]; then
    echo "Failed to download kepr"
    exit 1
fi

# Extract tarball
tar -xzf kepr.tar.gz

# Find the binary (it should be in the extracted directory)
BINARY_PATH=$(find . -name "kepr" -type f | head -1)

if [ -z "$BINARY_PATH" ]; then
    echo "kepr binary not found in tarball"
    exit 1
fi

# Install to $HOME/bin
mkdir -p $HOME/bin
cp "$BINARY_PATH" $HOME/bin/kepr
chmod +x $HOME/bin/kepr

popd > /dev/null
cleanup
```

**Step 2: Make script executable**

```bash
chmod +x /Users/galvarez/dev/gear/com/kepr/setup-darwin
```

**Step 3: Test script manually (if on macOS)**

```bash
# Only run if on darwin and kepr not already installed
rm -f $HOME/bin/kepr
/Users/galvarez/dev/gear/com/kepr/setup-darwin
$HOME/bin/kepr --version
```

Expected: kepr installs successfully and runs

**Step 4: Commit**

```bash
git add /Users/galvarez/dev/gear/com/kepr/setup-darwin
git commit -m "feat: add kepr setup script for darwin"
```

---

## Task 3: Create Linux Setup Script

**Files:**
- Create: `/Users/galvarez/dev/gear/com/kepr/setup-linux`

**Step 1: Write the setup script**

```bash
#!/usr/bin/env bash

export temp_path=$(mktemp -d)

function cleanup {
    rm -Rf "${temp_path}"
    set +e
}

set -e
trap cleanup EXIT

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
fi

# Fetch latest release version from GitHub API
VERSION=$(curl -s https://api.github.com/repos/gonzaloalvarez/kepr/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "Failed to fetch latest version"
    exit 1
fi

# Download the binary
DOWNLOAD_URL="https://github.com/GonzaloAlvarez/kepr/releases/download/${VERSION}/kepr-${VERSION}-linux-${ARCH}.tar.gz"

pushd . > /dev/null
cd "${temp_path}"

curl -sL "${DOWNLOAD_URL}" -o kepr.tar.gz

if [ ! -f kepr.tar.gz ]; then
    echo "Failed to download kepr"
    exit 1
fi

# Extract tarball
tar -xzf kepr.tar.gz

# Find the binary
BINARY_PATH=$(find . -name "kepr" -type f | head -1)

if [ -z "$BINARY_PATH" ]; then
    echo "kepr binary not found in tarball"
    exit 1
fi

# Install to $HOME/bin
mkdir -p $HOME/bin
cp "$BINARY_PATH" $HOME/bin/kepr
chmod +x $HOME/bin/kepr

popd > /dev/null
cleanup
```

**Step 2: Make script executable**

```bash
chmod +x /Users/galvarez/dev/gear/com/kepr/setup-linux
```

**Step 3: Commit**

```bash
git add /Users/galvarez/dev/gear/com/kepr/setup-linux
git commit -m "feat: add kepr setup script for linux"
```

---

## Task 4: Create Debian Setup Script

**Files:**
- Create: `/Users/galvarez/dev/gear/com/kepr/setup-debian`

**Step 1: Write the setup script**

```bash
#!/usr/bin/env bash

export temp_path=$(mktemp -d)

function cleanup {
    rm -Rf "${temp_path}"
    set +e
}

set -e
trap cleanup EXIT

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
fi

# Fetch latest release version from GitHub API
VERSION=$(curl -s https://api.github.com/repos/gonzaloalvarez/kepr/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$VERSION" ]; then
    echo "Failed to fetch latest version"
    exit 1
fi

# Download the binary (use linux binary for debian)
DOWNLOAD_URL="https://github.com/GonzaloAlvarez/kepr/releases/download/${VERSION}/kepr-${VERSION}-linux-${ARCH}.tar.gz"

pushd . > /dev/null
cd "${temp_path}"

curl -sL "${DOWNLOAD_URL}" -o kepr.tar.gz

if [ ! -f kepr.tar.gz ]; then
    echo "Failed to download kepr"
    exit 1
fi

# Extract tarball
tar -xzf kepr.tar.gz

# Find the binary
BINARY_PATH=$(find . -name "kepr" -type f | head -1)

if [ -z "$BINARY_PATH" ]; then
    echo "kepr binary not found in tarball"
    exit 1
fi

# Install to $HOME/bin
mkdir -p $HOME/bin
cp "$BINARY_PATH" $HOME/bin/kepr
chmod +x $HOME/bin/kepr

popd > /dev/null
cleanup
```

**Step 2: Make script executable**

```bash
chmod +x /Users/galvarez/dev/gear/com/kepr/setup-debian
```

**Step 3: Commit**

```bash
git add /Users/galvarez/dev/gear/com/kepr/setup-debian
git commit -m "feat: add kepr setup script for debian"
```

---

## Task 5: Create Remove Scripts

**Files:**
- Create: `/Users/galvarez/dev/gear/com/kepr/remove-darwin`
- Create: `/Users/galvarez/dev/gear/com/kepr/remove-debian`
- Create: `/Users/galvarez/dev/gear/com/kepr/remove-linux`

**Step 1: Write remove-darwin script**

```bash
#!/usr/bin/env bash

rm -f $HOME/bin/kepr
```

**Step 2: Write remove-debian script**

```bash
#!/usr/bin/env bash

rm -f $HOME/bin/kepr
```

**Step 3: Write remove-linux script**

```bash
#!/usr/bin/env bash

rm -f $HOME/bin/kepr
```

**Step 4: Make all scripts executable**

```bash
chmod +x /Users/galvarez/dev/gear/com/kepr/remove-darwin
chmod +x /Users/galvarez/dev/gear/com/kepr/remove-debian
chmod +x /Users/galvarez/dev/gear/com/kepr/remove-linux
```

**Step 5: Commit**

```bash
git add /Users/galvarez/dev/gear/com/kepr/remove-*
git commit -m "feat: add kepr remove scripts for all platforms"
```

---

## Task 6: Integration Testing

**Step 1: Test the full integration (darwin only)**

```bash
# Remove kepr if it exists
rm -f $HOME/bin/kepr

# Test gear wrapper
/Users/galvarez/dev/gear/run kepr --version
```

Expected: kepr installs automatically and displays version

**Step 2: Verify installation**

```bash
ls -la $HOME/bin/kepr
which kepr
```

Expected: Binary exists and is executable

**Step 3: Test removal**

```bash
/Users/galvarez/dev/gear/com/kepr/remove-darwin
ls -la $HOME/bin/kepr
```

Expected: Binary is removed

**Step 4: Document completion**

Create a summary of what was implemented and tested.

---

## Notes

- The setup scripts are very similar across platforms, differing only in the OS string used in the download URL
- Debian uses the linux binary since no debian-specific binary exists
- All scripts include error handling with `set -e` and cleanup with `trap EXIT`
- Architecture detection handles x86_64 → amd64 mapping, arm64 stays as-is
- GitHub API is used to always fetch the latest release version
