#!/usr/bin/env bash
#
# Install localllm (on-demand llama.cpp server wrapper) to ~/bin and ensure
# the llama.cpp runtime is present: Homebrew's prebuilt Metal llama-server on
# macOS; upstream's prebuilt Vulkan (or CPU) archive under
# ~/.local/opt/llama.cpp on x86_64 Linux. Shared by setup-darwin,
# setup-debian and setup-linux. Model downloads happen at RUNTIME
# (`localllm pull`/`serve`), never here — setup stays fast and gear's
# output-swallowing dispatch never hides a 12-22 GB download.
#
set -euo pipefail

LOCALLLM_VERSION="1.3.0"   # keep in sync with VERSION= in com/localllm/localllm (`gear info` greps the FIRST *VERSION= line — keep it this one)

# Linux runtime pin. llama.cpp publishes binaries under nightly build tags; the
# GitHub "latest" release (v0.6.0 at the time of writing) carries only a
# nightly-tag.txt pointing at one. Names below deliberately avoid "VERSION".
# Bump recipe:
#   tag=$(curl -fsSL https://github.com/ggml-org/llama.cpp/releases/download/<release>/nightly-tag.txt)
#   gh api repos/ggml-org/llama.cpp/releases/tags/$tag \
#     --jq '.assets[]|select(.name|test("ubuntu-(vulkan-)?x64.tar.gz$"))|[.name,.digest]|@tsv'
LLAMACPP_BUILD="b11429"
LLAMACPP_SHA256_VULKAN="632c4e98feba2b94407a2130e3133e0c3aefb0ea1ab41337e926d8bfafdd0b74"   # llama-b11429-bin-ubuntu-vulkan-x64.tar.gz
LLAMACPP_SHA256_CPU="f6d25dde8f51133143d1453da4fd5f73b145127177612a283bf7995957af3392"      # llama-b11429-bin-ubuntu-x64.tar.gz

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

# Linux: upstream prebuilt archive (flat layout: llama-<build>/{llama-server,
# llama-bench, libllama.so, libggml*.so, …}; the binaries find their libraries
# beside them, hence exec wrappers in ~/bin rather than bare symlinks). The
# Vulkan archive also carries the CPU backends and silently skips Vulkan when
# libggml-vulkan.so cannot load, so it is the default; LOCALLLM_LLAMA_FLAVOR=cpu
# picks the CPU-only archive (useful for a true CPU baseline in llama-bench).
# Root-level dependencies (libvulkan1, mesa-vulkan-drivers, libgomp1) are
# only reported — gear never sudoes.
install_llama_linux() {
    local arch; arch="$(uname -m)"
    if [ "$arch" != "x86_64" ]; then
        echo "localllm: no prebuilt llama.cpp for $arch — build it and set LLAMA_SERVER=/path/to/llama-server" >&2
        exit 1
    fi
    local flavor="${LOCALLLM_LLAMA_FLAVOR:-vulkan}" asset sha
    case "$flavor" in
        vulkan) asset="llama-${LLAMACPP_BUILD}-bin-ubuntu-vulkan-x64.tar.gz"; sha="$LLAMACPP_SHA256_VULKAN" ;;
        cpu)    asset="llama-${LLAMACPP_BUILD}-bin-ubuntu-x64.tar.gz";        sha="$LLAMACPP_SHA256_CPU" ;;
        *) echo "localllm: LOCALLLM_LLAMA_FLAVOR must be vulkan or cpu (got $flavor)" >&2; exit 1 ;;
    esac
    local base="$HOME/.local/opt/llama.cpp" dir="$HOME/.local/opt/llama.cpp/${LLAMACPP_BUILD}-${flavor}"
    if [ ! -x "$dir/llama-server" ]; then
        local stage; stage="$(mktemp -d)"
        # shellcheck disable=SC2064  # expand now: $stage is fixed for this run
        trap "rm -rf '$stage'" EXIT
        echo "localllm: fetching llama.cpp $LLAMACPP_BUILD ($flavor)"
        curl -fL --retry 3 -o "$stage/$asset" \
            "https://github.com/ggml-org/llama.cpp/releases/download/${LLAMACPP_BUILD}/${asset}"
        sha256_check "$stage/$asset" "$sha" || { echo "localllm: sha256 mismatch for $asset" >&2; exit 1; }
        mkdir -p "$stage/x"
        tar -xzf "$stage/$asset" -C "$stage/x" --strip-components=1
        if [ ! -x "$stage/x/llama-server" ]; then
            echo "localllm: archive layout changed — llama-server is not at the top level" >&2
            exit 1
        fi
        mkdir -p "$base"
        rm -rf "$dir"
        mv "$stage/x" "$dir"
        # Older builds of the same flavor are dead weight (gear update = remove + setup).
        find "$base" -mindepth 1 -maxdepth 1 -type d -name "b*-${flavor}" ! -name "${LLAMACPP_BUILD}-${flavor}" -exec rm -rf {} +
    fi
    ln -sfn "$dir" "$base/current"
    mkdir -p "$HOME/bin"
    local name
    for name in llama-server llama-bench; do
        # shellcheck disable=SC2016  # $HOME and $@ must stay literal in the generated wrapper
        printf '#!/usr/bin/env bash\nexec "$HOME/.local/opt/llama.cpp/current/%s" "$@"\n' "$name" > "$HOME/bin/$name"
        chmod +x "$HOME/bin/$name"
    done
    local missing
    missing="$(ldd "$dir/llama-server" 2>/dev/null | awk '/not found/{print $1}' | tr '\n' ' ')"
    if [ -n "$missing" ]; then
        echo "localllm: note: shared libraries missing: $missing" >&2
        echo "localllm: note: install them with apt (e.g. libvulkan1 mesa-vulkan-drivers libgomp1); gear does not sudo" >&2
    fi
    if ! "$HOME/bin/llama-server" --help >/dev/null 2>&1; then
        echo "localllm: llama-server does not run (see the note above)" >&2
        exit 1
    fi
    echo "localllm: llama.cpp $LLAMACPP_BUILD ($flavor) at $dir"
}

case "$(uname -s)" in
    Darwin)
        # Runtime dependency (keep this command's name off the brew line — gear's
        # available_version brew-detection regex keys on it).
        brew list llama.cpp >/dev/null 2>&1 || brew install llama.cpp
        ;;
    Linux)
        install_llama_linux
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
