# localllm + qwen Commands Design

**Date:** 2026-09-11 (amended same day: client/server split, qwen on Linux, caffeinate)
**Status:** Approved

## Overview

klaus (M4 Max MacBook, 36 GB) ran a hand-built local LLM stack: llama.cpp
compiled from source with Metal, a 21 GB Qwen GGUF parked in `~/Downloads`,
`llama-server` launched by hand in tmux with a long tuned flag set, the
qwen-code CLI installed ad-hoc via `npm -g`, and hand-written
`~/.qwen/settings.json` + `~/.qwen/.env`. Reproducing that on the next
personal Mac meant re-reading shell history. An amun plugin was evaluated
and rejected — the stack needs no root, no OS state and no daemon, macOS is
amun's weakest platform, and the §14.1 verification gate cannot exercise
Metal or a 22 GB model. This is gear + seshat territory: gear ships the
binaries and the operator command; the dotfiles bundle `llm.qwen.local`
owns the configuration.

Two commands:

- **`localllm`** — wrapper over brew's prebuilt Metal `llama-server`:
  `serve` / `pull` / `status` / `stop` / `config`. Models are pulled at
  runtime (resumable, sha256-verified) into
  `~/.local/share/localllm/models/`.
- **`qwen`** — the qwen-code CLI, npm global pinned to an exact version
  under brew node.

## Requirements

- One-command install on a fresh Mac (gear lazy dispatch), one command to
  serve, config declared per-device via seshat variables.
- No LaunchAgent, no resident 22 GB model: serve is foreground/on-demand
  (`tmux new -s llm 'localllm serve'`), matching real usage.
- Model download never happens in gear setup (gear's `run` swallows setup
  output — a 22 GB download would look like a hang) and must resume after
  interruption.
- Setup stays sudo-free; everything lands in `$HOME` (+ brew prefix via
  brew itself).

## Architecture

```
com/localllm/
├── setup-darwin      # exec install.sh
├── install.sh        # guard + brew llama.cpp + copy payload to ~/bin
├── remove-darwin     # rm ~/bin/localllm ONLY (see Key decisions)
└── localllm          # the payload (VERSION= answers --version)
com/qwen/
├── setup-darwin      # exec install.sh (brew node)
├── setup-linux       # exec install.sh (any node: system, mise, asdf)
├── install.sh        # npm install -g @qwen-code/qwen-code@<pin>
├── remove-darwin     # npm uninstall -g
└── remove-linux      # npm uninstall -g (same prefix logic)
```

Configuration precedence in the payload: built-in defaults (the
klaus-proven stack: Qwen3.8-27B-UD-Q6_K, 127.0.0.1:8080, ctx 65536, KV
q8_0) < `~/.config/localllm/config` (seshat-rendered KEY=VALUE, bundle
`localllm.server` in the dotfiles repo) < environment (`KV_QUANT=f16
localllm serve`). `LOCALLLM_CONFIG`, `LOCALLLM_DATA_DIR` and
`LLAMA_SERVER` relocate config/models/binary — tests use them so they
never touch real state.

Client/server topology (dotfiles side): the seshat bundles are split so a
machine can be either or both. `localllm.server` owns
`~/.config/localllm/config` (model, flags, `bind` — `127.0.0.1` serves
that machine only, `0.0.0.0` serves the LAN/tailnet) and requires
`localllm`; `llm.qwen.local` owns `~/.qwen/*` (client) with a
`server_host` variable (default `127.0.0.1`; point it at the serving
machine's IP/name for the remote topology) and requires only `qwen`, on
darwin AND linux. klaus installs both; a client-only box (e.g. the Omarchy
T14) installs just `llm.qwen.local`.

## Key decisions

- **brew's prebuilt llama.cpp over the historical source build.** Metal is
  enabled in the bottle; a cmake toolchain and a `~/dev/llama` checkout on
  every Mac bought nothing. `LLAMA_SERVER=` remains as an override for a
  custom build.
- **On-demand foreground serve, no LaunchAgent.** gear ships operator
  commands, not services (the ts precedent); a resident 22 GB model on a
  36 GB laptop is a real cost. `exec` after writing the pidfile makes the
  pidfile the server's own pid.
- **Runtime model download to a stable `.partial` path.** `curl -fL -C -`
  resume requires a stable partial path; gear's mktemp-staging house rule
  applies to install staging, not runtime artifacts. sha256 pinned from
  HuggingFace LFS metadata when set.
- **`stop` is identity-checked, never pkill.** The pid must both be alive
  and have comm `llama-server`; a recycled pid or a manually-run server is
  never killed. No `kill -9` — a stuck server is surfaced, not shot.
- **Conservative `remove-darwin`.** `gear update` = remove + setup;
  removing brew llama.cpp, models, or the seshat-owned config there would
  churn brew and orphan seshat state on every update. Wrapper only.
- **No foreign-binary guard for `qwen`.** npm's global bin
  (`/opt/homebrew/bin/qwen`) is exactly where our install lands — a
  kora-style guard would refuse forever on every machine that ever
  installed it. `localllm` keeps the guard (the moreutils-`ts` lesson).
- **Linux qwen installs sudo-free into `~/.local` when needed.** System
  npm prefixes like `/usr` (Omarchy ships system node) are root-owned;
  when the prefix isn't user-writable, `npm_config_prefix=$HOME/.local`
  puts the global under `~/.local/bin` (on PATH via the dotfiles). mise
  and asdf get a post-install reshim so the new bin resolves for gear's
  `command -v` gate. No node install on Linux — npm is required, with a
  pointer to `amun development` (the setup script's only hard dep).
- **`serve` holds a darwin idle-sleep assertion** (`caffeinate -i -w $$ &`
  before the exec): remote clients need the serving Mac awake, and `-w`
  ties the assertion to llama-server's own lifetime without disturbing the
  pidfile semantics. Lid-close still sleeps — a remote-serving Mac should
  be on power with the lid open (or use `caffeinate` display assertions
  out of band).
- **Speculative decoding is a first-class config key (`SPEC_TYPE`), not
  `EXTRA_ARGS`.** An unquoted two-word value in the sourced config file
  (`EXTRA_ARGS=--spec-type draft-mtp`) parses as an env-assignment plus a
  command — a landmine. `SPEC_TYPE=draft-mtp` is one token; the wrapper
  expands it to `--spec-type <value>` when set and non-`none`. Off by
  default: measured on klaus (M4 Max, Qwen3.8-27B UD-Q6_K, build 10809),
  draft-mtp is +33% on code at temp 0 (15.2 vs 11.4 tok/s), +15% at the
  qwen client's real sampling (13.7 vs 11.9, 78.8% acceptance), but
  **−13% on prose** (11.5 vs 13.2) — and upstream reports net LOSS on
  Metal for small/MoE models (ggml-org/llama.cpp#23752), so enable per
  machine/model only after an A/B benchmark. Requires MTP tensors in the
  GGUF (the unsloth Qwen3.8-27B file has them).
- **Exact npm pin** (`@qwen-code/qwen-code@0.23.3`) so `gear info`
  INSTALLED vs AVAILABLE comparison stays meaningful.

## Known limitations

- gear's `run` expands `$@` unquoted (run:51): subcommand args must stay
  space-free. All current subcommands are single words.
- Version pins (`LOCALLLM_VERSION`, `QWEN_VERSION`, the model sha256 in
  the payload defaults and the bundle) drift by hand, like every gear pin.
- `localllm` alone runs on built-in defaults; per-device model choice
  lives in the seshat bundle (`seshat install llm.qwen.local --set
  model_file=…`). If qwen-code's runtime rewrites a bundle-OWNED key in
  `~/.qwen/settings.json` (it normally only touches unmanaged keys like
  `/ui`), seshat blocks with exit 2 by design — remedy: re-run
  `seshat install llm.qwen.local`.
- `pull` against an already-complete `.partial` fails (HTTP 416): delete
  the `.partial` and re-pull.
- darwin-only. `setup-debian` (prebuilt Linux llama.cpp is CPU/Vulkan;
  CUDA needs a build) and the bundle's `platforms:` lift are the follow-up
  for aeolus-class machines.

## Amendment 2026-10-11 — Linux runtime and router mode (1.3.0)

- **Debian/Linux install.** `setup-debian`/`setup-linux` (+ `remove-*`) are
  one-line stubs into `install.sh`, which on x86_64 Linux downloads upstream's
  prebuilt archive (`llama-<build>-bin-ubuntu-vulkan-x64.tar.gz`, or the CPU
  archive with `LOCALLLM_LLAMA_FLAVOR=cpu`) from the nightly build tag behind
  the GitHub "latest" release (`v0.6.0` → `nightly-tag.txt` → `b11429`),
  verifies the GitHub-published sha256, unpacks it under
  `~/.local/opt/llama.cpp/<build>-<flavor>/` (flat layout; libraries beside
  the binaries) and writes exec wrappers `~/bin/llama-server`,
  `~/bin/llama-bench` through a `current` symlink. Pins live next to
  `LOCALLLM_VERSION` as `LLAMACPP_BUILD` + two digests (names avoid "VERSION"
  so `gear info` keeps reporting the command version). Root-level deps
  (libvulkan1, mesa-vulkan-drivers) are only reported — gear never sudoes.
- **Router mode** (opt-in via `MODEL2_ALIAS`): one `llama-server
  --models-preset ~/.local/state/localllm/models.ini --models-max N` exposes
  two model ids. The preset is regenerated on every `serve` from the config:
  shared flags in `[*]` (so an alias may override them), per-alias tokens from
  `MODEL_ARGS`/`MODEL2_ARGS` (`key=value`, long flag names, no spaces — JSON
  such as `chat-template-kwargs={"enable_thinking":false}` qualifies).
  `MODEL2_FILE` empty = the same GGUF under two aliases (Qwen3.8-27B as
  `-code` with thinking off and `-think` with `reasoning-effort`); set it for a
  second GGUF (`pull` fetches both). Nothing model-specific goes on the CLI:
  the router copies its CLI args onto every child. New keys also:
  `SERVER_ENV` (exported before exec, e.g. `GGML_VK_PREFER_HOST_MEMORY=1` for
  APUs) and `SLEEP_IDLE` (`--sleep-idle-seconds`, both modes). Single mode
  (klaus/minerva) is byte-for-byte the 1.2.0 invocation.
- **Service.** The dotfiles bundle ships a Linux-only `systemd --user` unit
  (`~/.config/systemd/user/localllm.service`); enabling it plus
  `loginctl enable-linger` is operator state. gear still ships only the command.
- **Pull** verifies with `sha256sum` (Linux) or `shasum` (macOS) and lets the
  checksum decide when `curl -C -` gets HTTP 416 on an already-complete
  `.partial`.
- First Linux host: travelblock.lan (Ryzen 7 7840U / Radeon 780M, RADV
  Vulkan). Known limitations above: "darwin-only" is lifted; prebuilt remains
  x86_64 Linux CPU/Vulkan (CUDA/ROCm need a build + `LLAMA_SERVER=`).
