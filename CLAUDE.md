# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

System configuration and utility scripts for Kiro / ArcoLinux-based desktops. It ships:
- **`usr/local/bin/`** — 40+ standalone utility scripts (pacman helpers, kernel variant installers, system info, DE fetchers)
- **`usr/local/lib/kiro-common.sh`** — unified shared library sourced by all scripts (80+ functions, 1000+ lines)
- **`etc/`** — drop-in config files for sysctl, udev, systemd, modprobe, X11, pacman hooks

## Deployment

There is no build step. Files are installed by copying them into place on the live system (matching the `usr/` and `etc/` directory tree). `setup-edu.sh` configures git remotes; `up.sh` commits and pushes.

## Shared library (`kiro-common.sh`)

Every script must source this library before doing anything else:

```bash
# shellcheck source=/usr/local/lib/kiro-common.sh
source /usr/local/lib/kiro-common.sh
```

Key sections and their functions:
- **Colors** — `$RED`, `$GREEN`, `$YELLOW`, `$BLUE`, `$CYAN`, `$BOLD`, `$RESET` (tput-based, disabled when not a terminal)
- **Logging** — `log_section`, `log_subsection`, `log_info`, `log_success`, `log_warn`, `log_error`
- **Error handling** — automatic `on_error` trap; scripts use `set -Euo pipefail`
- **Generic helpers** — `require_root_tools`, `replace_text_in_file`, `comment_out_patterns_in_file`, `show_help`, `execute_or_dryrun`
- **Package helpers** — `pkg_installed`, `install_packages`, `remove_packages`, `install_local_packages_from_dir`
- **Repo/pacman helpers** — add/remove/toggle repository entries in `pacman.conf`
- **Kernel/performance helpers** — sysctl, scheduler, CPU core utilities

## Script conventions

- First line after shebang: `set -Euo pipefail`
- Source `kiro-common.sh` before any logic
- Use library logging functions — never raw `echo` for user-facing output
- Root checks via `require_root_tools` or `[[ $EUID -ne 0 ]]` guard
- Avoid hard-coding paths that `kiro-common.sh` already provides

## Configuration file locations

| Path | Purpose |
|------|---------|
| `etc/sysctl.d/99-kiro-optimizations.conf` | Kernel tuning (memory, network, I/O, security) |
| `etc/udev/rules.d/60–68-*.rules` | Hardware tuning rules (I/O schedulers, GPU, USB, audio) |
| `etc/systemd/system.conf.d/` | Global systemd service/timeout/resource settings |
| `etc/modprobe.d/` | Driver options for AMD/Nvidia GPU, audio, ethernet |
| `etc/security/limits.d/` | ulimit overrides for audio and system processes |

## Configuration files — audit status (2026.05.18)

All `etc/` config files were audited and fixed. The set is now safe to deploy on general desktop and laptop hardware without hardware-specific breakage. Key outcomes:
- `etc/sysctl.d/99-kiro-optimizations.conf` — duplicate keys removed, security settings calibrated for usability (sysrq=244, ptrace_scope=1), comments corrected
- `etc/udev/rules.d/` — broken rules replaced or removed; NVIDIA GPU power rule removed (hangs); input rules rewritten with working sysfs paths
- `etc/systemd/` — journal storage changed to persistent; rate limiting fixed; timeouts increased to safe values
- `etc/modprobe.d/` — invalid r8169 parameters stripped; probe_mask removed; DPRINTK=1 removed; warnings added for amdgpu and nvidia single-user caveat

## Script improvement status

- Phase 1 (complete): unified library, error handling, variable quoting — all 33 scripts source `kiro-common.sh`
- Phases 2–4 (planned): `--help`/`--dry-run` flags, config files, full shellcheck/shfmt pass
