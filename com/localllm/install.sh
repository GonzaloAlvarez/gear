#!/usr/bin/env bash
#
# Install localllm (on-demand llama.cpp server wrapper) to ~/bin and ensure
# the llama.cpp runtime is present: upstream's prebuilt archive under
# ~/.local/opt/llama.cpp — Metal on Apple-silicon macOS, Vulkan (or CPU) on
# x86_64 Linux — pinned to a nightly build tag, sha256-verified, with exec
# wrappers in ~/bin. Shared by setup-darwin, setup-debian and setup-linux.
# Model downloads happen at RUNTIME (`localllm pull`/`serve`), never here —
# setup stays fast and gear's output-swallowing dispatch never hides a
# 12-22 GB download.
#
# Why upstream prebuilts on macOS too (1.4.0): Homebrew's bottle trails the
# nightlies by days to weeks (1.0.0 = b12359 while Inkling 2 Mini needed
# b12598+), one pin per platform is explicit, and the wrapper prefers
# ~/.local/opt/llama.cpp/current so whatever brew has on PATH no longer
# decides which build serves. LOCALLLM_LLAMA_FLAVOR=brew keeps the former
# Homebrew path (Intel Macs fall back to it: no prebuilt Metal archive).
#
set -euo pipefail

LOCALLLM_VERSION="1.5.0"   # keep in sync with VERSION= in com/localllm/localllm (`gear info` greps the FIRST *VERSION= line — keep it this one)

# Runtime pins. llama.cpp publishes binaries under nightly build tags; the
# GitHub "latest" release carries only a nightly-tag.txt pointing at one.
# Names below deliberately avoid "VERSION". One tag per platform — they need
# not match (bump each only after that platform's box was tested on it).
# Bump recipe:
#   tag=b12602
#   gh api repos/ggml-org/llama.cpp/releases/tags/$tag \
#     --jq '.assets[]|select(.name|test("(macos-arm64|ubuntu-(vulkan-)?x64).tar.gz$"))|[.name,.digest]|@tsv'
LLAMACPP_BUILD_DARWIN="b12602"   # 2026-11-21; inkling2_loop (Inkling 2 Mini) landed in b12598+
LLAMACPP_SHA256_METAL="bf9131abd5406665ec46348c6432b13adbd40f9ffad553af12116a82527965ae"    # llama-b12602-bin-macos-arm64.tar.gz
LLAMACPP_BUILD_LINUX="b11429"    # travelblock's proven build (Vulkan APU)
LLAMACPP_SHA256_VULKAN="632c4e98feba2b94407a2130e3133e0c3aefb0ea1ab41337e926d8bfafdd0b74"   # llama-b11429-bin-ubuntu-vulkan-x64.tar.gz
LLAMACPP_SHA256_CPU="f6d25dde8f51133143d1453da4fd5f73b145127177612a283bf7995957af3392"      # llama-b11429-bin-ubuntu-x64.tar.gz

LLAMA_BASE="$HOME/.local/opt/llama.cpp"

# A foreign binary already on PATH would win gear's `command -v` dispatch
# forever and this install would be dead code - refuse loudly instead.
existing="$(command -v localllm 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$existing" != "$HOME/bin/localllm" ]; then
    echo "localllm: a different binary is already on PATH at $existing - refusing to" >&2
    echo "localllm: shadow-install; remove it or rename it first" >&2
    exit 1
fi

sha256_check() {  # FILE EXPECTED
    if command -v sha256sum >/dev/null 2>&1; then
        echo "$2  $1" | sha256sum -c - >/dev/null
    else
        echo "$2  $1" | shasum -a 256 -c - >/dev/null
    fi
}

# Upstream prebuilt archive (flat layout: llama-<build>/{llama-server,
# llama-bench, libllama.*, libggml*.*, …}; the binaries find their libraries
# beside them — @rpath on macOS, RUNPATH on Linux — hence exec wrappers in
# ~/bin rather than bare symlinks). Root-level dependencies on Linux
# (libvulkan1, mesa-vulkan-drivers, libgomp1) are only reported — gear never
# sudoes. macOS binaries are linker-signed (ad hoc) and curl sets no
# quarantine attribute, so they run without Gatekeeper prompts.
install_llama_prebuilt() {  # BUILD FLAVOR ASSET SHA256
    local build="$1" flavor="$2" asset="$3" sha="$4"
    local dir="$LLAMA_BASE/${build}-${flavor}"
    if [ ! -x "$dir/llama-server" ]; then
        local stage; stage="$(mktemp -d)"
        # shellcheck disable=SC2064  # expand now: $stage is fixed for this run
        trap "rm -rf '$stage'" EXIT
        echo "localllm: fetching llama.cpp $build ($flavor)"
        curl -fL --retry 3 -o "$stage/$asset" \
            "https://github.com/ggml-org/llama.cpp/releases/download/${build}/${asset}"
        sha256_check "$stage/$asset" "$sha" || { echo "localllm: sha256 mismatch for $asset" >&2; exit 1; }
        mkdir -p "$stage/x"
        tar -xzf "$stage/$asset" -C "$stage/x" --strip-components=1
        if [ ! -x "$stage/x/llama-server" ]; then
            echo "localllm: archive layout changed — llama-server is not at the top level" >&2
            exit 1
        fi
        mkdir -p "$LLAMA_BASE"
        rm -rf "$dir"
        mv "$stage/x" "$dir"
        # Older builds of the same flavor are dead weight (gear update = remove + setup).
        find "$LLAMA_BASE" -mindepth 1 -maxdepth 1 -type d -name "b*-${flavor}" ! -name "${build}-${flavor}" -exec rm -rf {} +
    fi
    ln -sfn "$dir" "$LLAMA_BASE/current"
    mkdir -p "$HOME/bin"
    local name
    for name in llama-server llama-bench; do
        # shellcheck disable=SC2016  # $HOME and $@ must stay literal in the generated wrapper
        printf '#!/usr/bin/env bash\nexec "$HOME/.local/opt/llama.cpp/current/%s" "$@"\n' "$name" > "$HOME/bin/$name"
        chmod +x "$HOME/bin/$name"
    done
    if command -v ldd >/dev/null 2>&1; then
        local missing
        missing="$(ldd "$dir/llama-server" 2>/dev/null | awk '/not found/{print $1}' | tr '\n' ' ')"
        if [ -n "$missing" ]; then
            echo "localllm: note: shared libraries missing: $missing" >&2
            echo "localllm: note: install them with apt (e.g. libvulkan1 mesa-vulkan-drivers libgomp1); gear does not sudo" >&2
        fi
    fi
    if ! "$HOME/bin/llama-server" --help >/dev/null 2>&1; then
        echo "localllm: llama-server does not run (see the note above)" >&2
        exit 1
    fi
    echo "localllm: llama.cpp $build ($flavor) at $dir"
}

# Homebrew path (macOS, LOCALLLM_LLAMA_FLAVOR=brew or Intel): the wrapper
# prefers a pinned archive, so a leftover one must be unlinked for brew's
# binary to be the one that serves. Only OUR ~/bin exec wrappers are removed.
install_llama_brew() {
    # Runtime dependency (keep this command's name off the brew line — gear's
    # available_version brew-detection regex keys on it).
    brew list llama.cpp >/dev/null 2>&1 || brew install llama.cpp
    rm -f "$LLAMA_BASE/current"
    local name
    for name in llama-server llama-bench; do
        if [ -f "$HOME/bin/$name" ] && grep -q '.local/opt/llama.cpp/current' "$HOME/bin/$name" 2>/dev/null; then
            rm -f "$HOME/bin/$name"
        fi
    done
    echo "localllm: llama.cpp from Homebrew ($(brew list --versions llama.cpp 2>/dev/null || echo unknown))"
}

case "$(uname -s)" in
    Darwin)
        flavor="${LOCALLLM_LLAMA_FLAVOR:-metal}"
        if [ "$flavor" = "metal" ] && [ "$(uname -m)" != "arm64" ]; then
            echo "localllm: no prebuilt Metal archive for $(uname -m) — falling back to Homebrew" >&2
            flavor="brew"
        fi
        case "$flavor" in
            metal) install_llama_prebuilt "$LLAMACPP_BUILD_DARWIN" metal \
                       "llama-${LLAMACPP_BUILD_DARWIN}-bin-macos-arm64.tar.gz" "$LLAMACPP_SHA256_METAL" ;;
            brew)  install_llama_brew ;;
            *) echo "localllm: LOCALLLM_LLAMA_FLAVOR must be metal or brew on macOS (got $flavor)" >&2; exit 1 ;;
        esac
        ;;
    Linux)
        if [ "$(uname -m)" != "x86_64" ]; then
            echo "localllm: no prebuilt llama.cpp for $(uname -m) — build it and set LLAMA_SERVER=/path/to/llama-server" >&2
            exit 1
        fi
        # The Vulkan archive also carries the CPU backends and silently skips
        # Vulkan when libggml-vulkan.so cannot load, so it is the default;
        # LOCALLLM_LLAMA_FLAVOR=cpu picks the CPU-only archive (a true CPU
        # baseline for llama-bench).
        flavor="${LOCALLLM_LLAMA_FLAVOR:-vulkan}"
        case "$flavor" in
            vulkan) install_llama_prebuilt "$LLAMACPP_BUILD_LINUX" vulkan \
                        "llama-${LLAMACPP_BUILD_LINUX}-bin-ubuntu-vulkan-x64.tar.gz" "$LLAMACPP_SHA256_VULKAN" ;;
            cpu)    install_llama_prebuilt "$LLAMACPP_BUILD_LINUX" cpu \
                        "llama-${LLAMACPP_BUILD_LINUX}-bin-ubuntu-x64.tar.gz" "$LLAMACPP_SHA256_CPU" ;;
            *) echo "localllm: LOCALLLM_LLAMA_FLAVOR must be vulkan or cpu on Linux (got $flavor)" >&2; exit 1 ;;
        esac
        ;;
    *)
        echo "localllm: unsupported platform $(uname -s)" >&2
        exit 1
        ;;
esac

__DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p "$HOME/bin"
cp "$__DIR/localllm" "$HOME/bin/localllm"
chmod +x "$HOME/bin/localllm"
echo "localllm installed: $HOME/bin/localllm (v$LOCALLLM_VERSION)"
echo "note: config is seshat-owned - install it with: seshat install localllm.server"
