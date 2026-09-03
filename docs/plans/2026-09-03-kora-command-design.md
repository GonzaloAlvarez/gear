# gear command: kora

## Overview

`kora` (repo: [GonzaloAlvarez/kora](https://github.com/GonzaloAlvarez/kora))
manages exactly one VM at a time — local (tart on Apple Silicon, QEMU+hvf for
arch, QEMU+KVM cloud images on Linux) or cloud (a QEMU/KVM guest on the
persistent `kvm` clouddevbox, one per AWS profile). It replaces the VM
machinery that used to live inside `amun/test` (tart lifecycle, archboot
QEMU install, clouddevbox orchestration) with a standalone operator tool;
`amun/test` and every `amun-*/test` wrapper now delegate to it.

## Requirements

- Own public repo, single-file sh/python polyglot, stdlib-only (no venv).
- Distributed the clouddevbox way: curl the raw file from `main` to
  `~/bin/kora`. Publishing = pushing to main.
- macOS (darwin) + Debian + generic Linux. No Termux: untested on bionic, and
  gear policy forbids a silent termux→linux fallback.

## Architecture

```
com/kora/
├── install.sh        # KORA_VERSION pin, foreign-kora guard, curl raw main,
│                     # per-OS soft-dependency hints (tart/qemu/clouddevbox)
├── setup-darwin      # exec install.sh
├── setup-debian      # exec install.sh
├── setup-linux       # exec install.sh
└── remove-*          # rm -f ~/bin/kora
```

## Key decisions

- **Foreign-`kora` guard**: PyPI/npm both have unrelated `kora` packages. If
  `command -v kora` resolves to anything other than `~/bin/kora`, install.sh
  refuses instead of shadow-installing a binary gear's dispatch would never
  reach (the moreutils-`ts` lesson from `2026-08-29-ts-command-design.md`).
- **`KORA_VERSION` pinned in install.sh** so `gear info` reports AVAILABLE
  (clouddevbox/thoth show `unknown` because raw-URL installs carry no pin).
- **Soft dependencies are printed hints**, not installs: tart/sshpass/qemu on
  darwin, qemu-system-x86 + genisoimage (or the amun `qemu` plugin) on Linux,
  clouddevbox for `--cloud`.

## Known limitations

- Version drift: the pin in install.sh must be bumped alongside `VERSION=` in
  the kora repo, by hand.
- `gear update kora` re-curls main; there is no changelog surface beyond the
  kora repo's git history.
