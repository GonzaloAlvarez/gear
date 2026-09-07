# gear commands: awscost, awsdashboard

## Overview

Two commands from one repo,
[GonzaloAlvarez/awsutils](https://github.com/GonzaloAlvarez/awsutils):

- `awscost` — this month's AWS spend broken down by service, from Cost
  Explorer. Hides services under $0.10.
- `awsdashboard` — picks an assumable role and prints a federated console
  sign-in URL. Replaces the never-installed `pyawsah` (now archived), whose
  Click+loguru package needed a pip install that never happened on any machine.

Both are single-file Python scripts in the clouddevbox idiom: a throwaway venv
(`boto3` + `bullet`) per run under `~/.<toolname>`, removed on exit. Profile
selection is the shared `bullet` picker that auto-selects a lone profile.

## Requirements

- One public repo, two executables at its root, each curl-able on its own.
- Distributed the clouddevbox way: curl the raw file from `main` to
  `~/bin/<name>`. Publishing = pushing to main.
- macOS (darwin) + Debian + generic Linux — `setup-linux` matters here, this is
  an Arch/Omarchy box and gear's osstr resolves to `linux`. No Termux: boto3 on
  bionic is untested and gear policy forbids a silent termux→linux fallback.

## Architecture

```
com/awscost/
├── install.sh        # AWSCOST_VERSION pin, foreign-awscost guard, curl raw
│                     # main, hints (python3/venv/boto3, ~/.aws, $0.01 a run)
├── setup-{darwin,debian,linux}   # exec install.sh
└── remove-{darwin,debian,linux}  # rm -f ~/bin/awscost

com/awsdashboard/     # same seven files; hints swap the Cost Explorer charge
                      # for xdg-open/open (needed by --open) and a note that
                      # every call it makes is free
```

## Key decisions

- **Two components, one repo.** gear's contract is that the `com/<dir>` name is
  the executable on PATH, so two commands need two directories. `gear info`
  reads the explicit `*_VERSION` pin before it ever reaches its
  `github.com/OWNER/REPO` fallback, so both components pointing at the same repo
  is unambiguous.
- **`--version` short-circuits before the venv bootstrap.** `gear info` runs
  `<name> --version` with an 8s timeout; a bootstrap (10-20s of pip) would blow
  through it and report INSTALLED as `unknown`. Both scripts answer `--version`
  and `--help` from argparse-only code paths, in ~30ms.
- **Version pins in install.sh** (`AWSCOST_VERSION`, `AWSDASHBOARD_VERSION`) so
  `gear info` reports AVAILABLE — raw-URL installs carry no pin otherwise, which
  is why clouddevbox and thoth show `unknown`.
- **Foreign-binary guard** in both install scripts (the moreutils-`ts` lesson
  from `2026-08-29-ts-command-design.md`): if `command -v <name>` resolves
  anywhere other than `~/bin/<name>`, refuse rather than shadow-install
  something gear's dispatch would never reach.
- **Soft dependencies are printed hints**, not installs: python3 + its venv
  module, and the observation that pre-installing `boto3`/`bullet` with
  `pip install --user` skips the per-run bootstrap entirely.
- **`awscost` warns that it costs money** — one `ce:GetCostAndUsage` per run at
  $0.01. `awsdashboard` says the opposite, because every call it makes is free.

## Known limitations

- Two version pins to bump by hand against one repo, and neither is checked
  against the script's own `VERSION` constant.
- `gear update <name>` re-curls main; the only changelog is the awsutils git
  history.
- Cost Explorer must be enabled once in the billing console by the payer
  account; the install script can't detect that, so a first `awscost` run may
  fail with an explanatory error instead.
