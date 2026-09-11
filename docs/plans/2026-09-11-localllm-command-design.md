# localllm + qwen Commands Design

**Date:** 2026-09-11
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
├── setup-darwin      # exec install.sh
├── install.sh        # brew node + npm install -g @qwen-code/qwen-code@<pin>
└── remove-darwin     # npm uninstall -g
```

Configuration precedence in the payload: built-in defaults (the
klaus-proven stack: Qwen3.8-27B-UD-Q6_K, 127.0.0.1:8080, ctx 65536, KV
q8_0) < `~/.config/localllm/config` (seshat-rendered KEY=VALUE, bundle
`llm.qwen.local` in the dotfiles repo) < environment (`KV_QUANT=f16
localllm serve`). `LOCALLLM_CONFIG`, `LOCALLLM_DATA_DIR` and
`LLAMA_SERVER` relocate config/models/binary — tests use them so they
never touch real state.

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
