# opencode Command Design

**Date:** 2026-11-21
**Status:** Approved (shipped same day)

## Why

OpenCode (https://opencode.ai, anomalyco/opencode, MIT) is the harness the
operator picked for the **local** rows of the LLM router: it speaks OpenAI
chat completions natively (no Anthropic→OpenAI translation in LiteLLM),
declares per-model context limits so compaction fires at the real 64k/32k
window, ships a small toolset, and Collie supports it. Claude Code stays the
harness for the Claude rows. Trigger: the Collie-on-klaus session with
qwen-code, which Collie cannot name as an agent.

## Install (`com/opencode`)

- Pinned GitHub release binary, sha256 per platform (`darwin-arm64.zip`,
  `linux-x64.tar.gz`, `linux-arm64.tar.gz`; each holds one top-level
  `opencode`), `install -m 0755` into `~/bin`. Pin `2.3.2` (2026-11-18) —
  the GitHub "latest" label and the npm `latest` tag still pointed at the
  last 1.x (1.19.6) at pin time, so neither "latest" mechanism was usable.
- Not brew (formula lands outside `~/bin`, lags), not npm (needs node, wrong
  "latest"). Foreign-binary guard like herdr/kauket. No Termux build.
- `--version` prints `opencode v2.3.2`; gear's installed-version regex takes
  the digits. `OPENCODE_VERSION=` is the first `*VERSION=` line for
  `gear info`. Self-update is disabled by the bundle config so gear owns
  the version (`gear update opencode` after bumping the pin + digests).

## Config (dotfiles `llm.client`, target `opencode.config`)

- `~/.config/opencode/opencode.json`, `json_merge` owning
  `/autoupdate /share /model /small_model /provider` (no `$schema`: seshat's
  owns pointers allow `[A-Za-z0-9_.-]` only). Provider `llmrouter` =
  `@ai-sdk/openai-compatible` at `<router_url>/v1`, `apiKey: open`, one
  model per router row with `tool_call`, `reasoning`, `attachment` and
  `limit` (the same row list the claude/qwen templates carry); optional
  provider `local` (direct llama-server) from `local_host`/`local_alias*`.
  `model = llmrouter/<default_model>`, `small_model = llmrouter/<small_model>`
  (new variable, default `deepseek-flash`, the counterpart of Claude Code's
  haiku pin). `share = disabled`, `autoupdate = false`.
- Rendered on every `llm.client` machine without requiring the command
  (herdr-config precedent): inert until `opencode --version` lazy-installs.
  The legacy `provider` shape is accepted by both 1.19.6 and 2.3.2 (checked
  with `opencode models` under a throwaway HOME); the newer `providers`
  shape is 2.x-only and was not needed.

## Verified before rollout (work Mac, throwaway HOME)

`opencode run -m llmrouter/qwen-klaus` over TLS answered; a bash tool call
through the router ran and was reported; `opencode models` lists the rows.
First deployment: klaus.
