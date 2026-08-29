# ts Command Design

**Date:** 2026-08-29
**Status:** Approved

## Overview

Add `ts`, a personal tailnet client wrapper for the headscale control plane at
https://hs.gn.al, replacing GUI Tailscale clients on personal machines. Motivating
incident: on a personal MacBook, quitting the Tailscale menu-bar app did not stop the
VPN — its network extension kept running headless and held the headscale DNS override,
silently breaking all `.lan` resolution. `ts` wraps the open-source `tailscaled`
(installed by amun-tailscale) so up/down state is explicit, scriptable, and honest.

## Requirements

- `ts up` — connect to headscale with `--accept-dns` and `--accept-routes` so
  `lab.gn.al` / `ts.gn.al` names resolve and subnet routes work.
- `ts status` — connected/disconnected; full `tailscale status` when up; exit 0/1.
- `ts down` — disconnect.
- macOS + Linux (debian and generic). No Termux (Android uses the Tailscale app).
- macOS only: a minimal gray menu-bar dot visible while connected, gone when not.

## Architecture

Follows gear's existing pattern (kauket-style shared `install.sh` + thin `setup-*`
wrappers; fixdocker precedent for shipping our own payload):

- `com/ts/ts` — the command, copied to `$HOME/bin/ts`.
- `com/ts/ts-indicator.swift` — menu-bar dot source, compiled to `$HOME/bin/ts-indicator`
  by `install.sh` when `swiftc` exists (Xcode CLT); otherwise skipped with a warning and
  lazily retried by `ts up` from `~/.gear/com/ts/ts-indicator.swift`.
- `setup-darwin`/`setup-debian`/`setup-linux` → `exec install.sh`; matching `remove-*`.
- `TS_VERSION` in `install.sh` + `ts --version` feed `gear info`.

## Key decisions

- **Idempotent up via `--reset` + full canonical flag set.** `tailscale up` refuses
  changed flags on an already-up node; `--reset` makes prefs exactly this flag set every
  run: `--reset --login-server=https://hs.gn.al --accept-routes --accept-dns=true
  --hostname=$(hostname -s, lowercased)`. `TS_AUTHKEY` env adds `--authkey` for first
  registration (mint on the VPS: `headscale preauthkeys create --user 2 --expiration 1h`);
  without it the headscale auth URL passes through to the terminal.
- **No jq/python dependency.** BackendState parsed from `tailscale status --peers=false
  --json` with whitespace-tolerant grep.
- **Indicator honesty.** The dot process polls the backend every 5s and exits the moment
  BackendState != Running, and refuses to start unless Running. It can therefore never
  show "connected" when the VPN is down — the property the GUI app lacked. No menu, no
  clicks: NSStatusItem with a "●" in `secondaryLabelColor` (adapts light/dark),
  `.accessory` activation policy (no Dock icon).
- **pgrep/pkill `-x ts-indicator`, no PID file.** Self-healing across crashes/reboots;
  process name is unique. `ts down` pkills immediately; the 5s self-poll is the backstop
  when tailscale is downed outside `ts`. `ts status` reconciles (starts the dot if
  connected and missing).
- **sudo at runtime, not at setup.** gear setup scripts stay sudo-free (house rule);
  `tailscale up/down` needs root and `ts` calls sudo itself. If tailscaled is down,
  `ts up` attempts a start (launchctl bootstrap/kickstart on macOS, systemctl on Linux)
  before giving up with a pointer to `amun tailscale`.

## Known limitations

- The dot does not auto-appear after a machine reboot (tailscaled reconnects on its own)
  until the next `ts` invocation. A login LaunchAgent is a possible follow-up.
- The dot only runs in a GUI session; `ts up` over SSH connects fine but shows no dot.
- While connected with accept-dns, `.lan` names do not resolve (headscale pushes
  1.1.1.1 with override-local-dns); `ts down` restores home DNS. A headscale split-DNS
  route `lan → 10.2.0.1` is a possible tailnet-wide follow-up.
- On Linux hosts that ship moreutils' `/usr/bin/ts`, gear's lazy-install alias resolves
  to that binary and never installs ours.
