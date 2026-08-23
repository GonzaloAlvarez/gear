# gear

Lazy per-user binary installer. Cloned by amun to `~/.gear`; the dotfiles wire
`~/.gear/commands.sh` (aliases every `com/<name>` to `run <name>`) and prepend
`~/.gear/util` to PATH. A command installs on first use via
`com/<name>/setup-<osstr>`.

## OS detection

`run`, `cleanup`, and `gear` resolve `<osstr>` identically:

| osstr | condition |
|---|---|
| `termux` | `TERMUX_VERSION` env var set (the repo-wide Termux signal — never `$PREFIX` checks) |
| `darwin` | `uname -s` = Darwin |
| `debian` | Linux with `/etc/debian_version` |
| `linux`  | any other Linux |

There is deliberately **no termux→linux fallback**: Termux has no sudo and a
bionic userland, so a `setup-linux` script that happens to "work" is a trap.
A command supports Termux only when it ships an explicit `setup-termux`.

## Termux support

Commands with `setup-termux`/`remove-termux`: `kauket`, `clouddevbox`, `gh`
(installed from the Termux `pkg` repo).

- `kauket`: installs the PIE `android_arm64` artifact (kauket >= 2.2.1). The
  linux artifact is non-PIE and the Play-build Termux runs binaries through
  the Android system linker, which rejects it with `unexpected e_type: 2`;
  kauket 2.2.1 also ships an argv shim for system_linker_exec and a DNS
  fallback resolver (no `/etc/resolv.conf` on Android; override with
  `KAUKET_DNS`). Note Docker containers mask both issues — only a real
  device proves them.
- `clouddevbox`: everything except `ssm` (no aws CLI / session-manager-plugin
  builds for bionic). Use `clouddevbox ssh` over the Tailscale app's VPN.
