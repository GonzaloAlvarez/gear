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

Commands with `setup-termux`/`remove-termux`: `kauket`, `clouddevbox`.

- `kauket`: the static linux_arm64 Go binary runs on bionic, but pure-Go DNS
  resolution can fail on a real Android device (no `/etc/resolv.conf`; Docker
  containers inject one, so container tests don't prove it). If kauket cannot
  resolve GitHub on-device, that needs a kauket-side resolver fallback.
- `clouddevbox`: everything except `ssm` (no aws CLI / session-manager-plugin
  builds for bionic). Use `clouddevbox ssh` over the Tailscale app's VPN.
