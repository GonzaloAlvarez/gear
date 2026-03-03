# kepr Integration Design

**Date:** 2026-03-03
**Status:** Approved

## Overview

Add kepr application to gear's auto-install system. kepr is a tool from github.com/gonzaloalvarez/kepr that should be installed by downloading pre-built binaries from GitHub releases.

## Requirements

- Support all three platforms: darwin (macOS), debian, and linux
- Download latest release automatically from GitHub
- Install binary to `$HOME/bin/kepr`
- Support both architectures: amd64 and arm64 (for darwin)

## Architecture

Follow gear's existing pattern:
- Directory structure: `/com/kepr/`
- Setup scripts: `setup-darwin`, `setup-debian`, `setup-linux`
- Remove scripts: `remove-darwin`, `remove-debian`, `remove-linux`

Each setup script will:
1. Detect the system architecture (amd64/arm64)
2. Fetch the latest release version from GitHub API
3. Download the appropriate binary tarball
4. Extract and install to `$HOME/bin/kepr`
5. Clean up temporary files

## Implementation Details

### Setup Scripts

**Architecture Detection:**
- Darwin: `uname -m` returns `x86_64` (map to amd64) or `arm64`
- Linux: `uname -m` returns `x86_64` (map to amd64)

**Version Discovery:**
- API endpoint: `https://api.github.com/repos/gonzaloalvarez/kepr/releases/latest`
- Parse JSON response to extract `tag_name` field

**Download URL Format:**
```
https://github.com/GonzaloAlvarez/kepr/releases/download/${VERSION}/kepr-${VERSION}-${OS}-${ARCH}.tar.gz
```

Where:
- `${VERSION}` is the tag_name from API (e.g., v0.1.0-rc1)
- `${OS}` is darwin or linux
- `${ARCH}` is amd64 or arm64

**Installation Flow:**
1. Create temporary directory with `mktemp -d`
2. Download tarball using `curl -sL`
3. Extract tarball with `tar -xzf`
4. Create `$HOME/bin` directory if it doesn't exist
5. Move `kepr` binary to `$HOME/bin/kepr`
6. Make executable with `chmod +x`
7. Cleanup temp directory using `trap EXIT`

**Error Handling:**
- Use `set -e` to exit on any error
- Verify curl succeeds
- Check that binary exists after extraction
- Use trap for guaranteed cleanup

### Remove Scripts

Simple implementation:
```bash
#!/usr/bin/env bash
rm -f $HOME/bin/kepr
```

## Available Releases

Current latest release: v0.1.0-rc1

Available binaries:
- kepr-v0.1.0-rc1-darwin-amd64.tar.gz
- kepr-v0.1.0-rc1-darwin-arm64.tar.gz
- kepr-v0.1.0-rc1-linux-amd64.tar.gz

## Testing

Manual testing required for each platform:
1. Remove kepr if installed: `rm -f $HOME/bin/kepr`
2. Run gear wrapper: `/path/to/gear/run kepr --version`
3. Verify kepr installs and runs successfully
4. Verify binary is in `$HOME/bin/kepr`

## Future Considerations

- Currently no debian-specific release (will use linux-amd64)
- No ARM Linux support in releases yet
- Could add checksum verification using checksums.txt from releases
