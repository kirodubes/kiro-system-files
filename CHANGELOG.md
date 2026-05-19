# CHANGELOG

## 2026.05.19 (session 2)

**What Changed**
Added `kiro-enable-ssh` — a one-step script that installs `openssh` and immediately enables/starts `sshd`. Fixed incorrect use of `log_error` for a user-facing root-check message.

**Technical Details**
- Script follows the Phase 2 pattern: sources `kiro-common.sh`, supports `--help`/`--version`/`--dry-run`, requires root via `[[ $EUID -ne 0 ]]` guard
- `log_error` in `kiro-common.sh` is the ERR trap handler — it takes `lineno`/`cmd` params, not a message string. Calling it with a plain string produces the full `⚠️ ERROR DETECTED` banner with the message treated as a line number. Root-check failures (and any user-facing error before the trap can fire) must use `echo "${RED}...${RESET}" >&2` instead
- Man pages belong in `usr/share/man/man8/` (maps to `/usr/share/man/man8/` on deploy) — the path is correct. `mandb` runs on a daily systemd timer (`man-db.timer`) with up to 12h random delay, not at boot. Run `sudo mandb` manually after deploying new pages to get immediate tab completion

**Files Modified**
- `usr/local/bin/kiro-enable-ssh` (new)
- `usr/share/man/man8/kiro-enable-ssh.8` (new)

---

## 2026.05.19

**What Changed**
Added `kiro-lint` — a static config analyser that checks the `etc/` tree before deployment.

**Technical Details**
Four checks implemented:
- **Sysctl duplicate keys**: parses each `sysctl.d/*.conf`, joins backslash-continuation lines, flags any key that appears more than once in the same file (last write wins, earlier value is silently lost)
- **Modprobe params vs sysfs**: for each `options <driver> param=val` in `modprobe.d/`, verifies the param is exposed under `/sys/module/<driver>/parameters/`; skips gracefully when the module isn't loaded; detected `snd_hda_intel.stateful_codec` as absent from lqx 7.0.9 kernel
- **Cross-file conflicts**: builds a map of all modprobe param values, detects same driver/param set to different values across files, then checks udev `ATTR{}` write targets for param names that match — flags anything where udev would silently override the modprobe value at runtime
- **Udev ATTR write targets**: extracts `ATTR{path}="value"` write assignments (distinguished from `==` match conditions via PCRE negative lookbehind), resolves the KERNEL= pattern to a sysfs search base, and verifies the attribute path exists on a live device; SKIPs cleanly when no matching hardware is present
- Script accepts `--source <path>` to analyse a repo tree before deployment (default: `/` for installed files); no root required

**Files Modified**
- `usr/local/bin/kiro-lint` (new)
- `TODO.md`
- `CHANGELOG.md`

---

## 2026.05.18 (session 3)

**What Changed**
Complete audit and fix of all `etc/` configuration files — sysctl, udev rules, systemd drop-ins, modprobe options. 23 issues resolved across Critical / High / Medium / Low / Documentation categories. Every config file the package ships is now safe to deploy on a general desktop or laptop without hardware-specific breakage.

**Technical Details**
- **Critical**: `probe_mask=1` removed from `audio-hda.conf` (was blocking HDMI audio by limiting HDA bus scan to first codec); `jackpoll_ms=0` → `500` (0 disabled headphone jack detection); `61-audio-power.rules` was a verbatim copy of `60-io-scheduler.rules` — replaced with correct USB/PCIe audio power management; `DPRINTK=1` removed from `intel-ethernet.conf` (was flooding journal on any Intel e1000e NIC)
- **High**: `kernel.sysrq=0` → `244` (REISUB bitmask: R+E+I+S+U+B); `ptrace_scope=2` → `1` (2 breaks gdb/strace/IDE debuggers); `DefaultTimeoutStartSec=10s` → `30s` (10s killed databases and Samba on first start); watchdog block commented out (iTCO_wdt and sp5100_tco are blacklisted so `/dev/watchdog` never exists); journal `Storage=volatile` → `persistent` (volatile lost all logs on reboot); journald file had three concatenated blocks with conflicting duplicate keys — rate limiting ended up clobbered to 0/0 (disabled entirely); NVIDIA `power/control=auto` udev rule removed (causes GPU hangs on GTX 900/1000 series)
- **Medium**: `vm.dirty_ratio`/`vm.dirty_background_ratio` removed (silently ignored when `dirty_bytes` is set); duplicate sysctl keys deduplicated (kptr_restrict×2, netdev_max_backlog×2, tcp_fastopen×2, entire BBR/fq block×2); NVMe `set-feature -f 2` rule removed (feature ID 2 is Write Atomicity Normal, not APST); `hdparm -M 128` removed (was mislabelled as TRIM — actually Acoustic Management, mostly ignored by modern drives); `68-sound-power.rules` had `power_save=10` conflicting with `modprobe.d` `power_save=0`; `realtek-ethernet.conf` invalid r8169 parameters stripped and `use_dac=1` reverted to safe default; `amdgpu.conf` instability warning added for early Vega/Navi
- **Low**: `kernel.unprivileged_userns_clone` removed (hardened-kernel-only sysctl, causes errors on vanilla Arch); `66-input-optimization.rules` rewritten — all four previous rules were no-ops (non-existent procfs path, fake libinput env vars, wrong usbhid jitter direction); `DefaultTasksMax=infinity` → `65536`; user subsequently refined the USB HID autosuspend rules to correctly match on `usb_interface` and write to the parent device node via `dirname %p`
- **Documentation**: `overcommit_ratio=50` comment updated to note it is ignored when `overcommit_memory=1`; `sched_autogroup_enabled=0` trade-off documented (correct for single-user audio desktop, reduces fairness on multi-user systems); `nvidia.conf` `NVreg_InitializeSystemMemoryAllocations=0` single-user caveat added

**Files Modified**
- `etc/modprobe.d/audio-hda.conf`
- `etc/modprobe.d/amdgpu.conf`
- `etc/modprobe.d/intel-ethernet.conf`
- `etc/modprobe.d/nvidia.conf`
- `etc/modprobe.d/realtek-ethernet.conf`
- `etc/sysctl.d/99-kiro-optimizations.conf`
- `etc/systemd/journald.conf.d/10-kiro-journal.conf`
- `etc/systemd/system.conf.d/10-kiro-system.conf`
- `etc/udev/rules.d/61-audio-power.rules`
- `etc/udev/rules.d/64-gpu-optimization.rules`
- `etc/udev/rules.d/65-storage-optimization.rules`
- `etc/udev/rules.d/66-input-optimization.rules`
- `etc/udev/rules.d/68-sound-power.rules`

---

## 2026.05.18 (session 2)

**What Changed**
All 33 scripts in `usr/local/bin/` that were not sourcing the shared library have been updated. Every script in the project now sources `/usr/local/lib/kiro-common.sh` for uniform logging, colors, and error handling.

**Technical Details**
Scripts were processed in four tiers:
- **Tier 1** (16 scripts): Standard transform — `#set -e` replaced with `set -Euo pipefail`, source block added, echo banners replaced with `log_section`/`log_info`/`log_success`/`log_warn`/`log_error`
- **Tier 2** (9 scripts): Same as Tier 1 plus removal of inline tput color variable blocks and inline `tput setaf`/`tput sgr0` calls, replaced by library log functions
- **Tier 3** (7 scripts): Careful handling — duplicate local `check_connectivity()` in `var` removed in favour of the library's version; ANSI display code in `sysinfo`, `sysinfo-retro`, `fetch`, `hfetch`, `sfetch` preserved untouched (display formatting, not logging); custom domain functions in `fix-sddm-conf` and `get-chadwm`/`get-sddm-simplicity` kept and cleaned of tput calls
- **Tier 4** (1 script): `pci-latency` — shebang changed from `#!/usr/bin/env sh` to `#!/bin/bash`; `set +e` preserved intentionally (script must continue on setpci failures); `set -Euo pipefail` deliberately omitted
- `get-arcolinux-nemesis` turned out to be a symlink to `get-nemesis` — one edit covered both
- Deprecated `$[count+1]` arithmetic replaced with `$((count+1))` in `get-chadwm` and `get-sddm-simplicity`
- `remove-socials` rm calls changed to `rm -f` to be safe under `set -Euo pipefail`
- All 44 scripts syntax-checked with `bash -n` — zero errors

**Files Modified**
- `usr/local/bin/iso`
- `usr/local/bin/edu-get-mirrors`
- `usr/local/bin/edu-probe`
- `usr/local/bin/edu-set-cores`
- `usr/local/bin/edu-which-vga`
- `usr/local/bin/edu-fix-archlinux-servers`
- `usr/local/bin/edu-fix-pacman-gpg-conf`
- `usr/local/bin/get-linux-mainline-x64v3-from-chaotic-repo`
- `usr/local/bin/get-linux-nitrous-from-chaotic-repo`
- `usr/local/bin/get-linux-xanmod-edge-x64v3-from-chaotic-repo`
- `usr/local/bin/get-linux-xanmod-lts-from-chaotic-repo`
- `usr/local/bin/remove-chaotic-repo-from-pacman.conf`
- `usr/local/bin/remove-nemesis-repo-from-pacman.conf`
- `usr/local/bin/toggle-chaotic-repo`
- `usr/local/bin/skel`
- `usr/local/bin/velo`
- `usr/local/bin/get-nemesis` (also covers `get-arcolinux-nemesis` symlink)
- `usr/local/bin/get-flexi`
- `usr/local/bin/use`
- `usr/local/bin/remove-debug`
- `usr/local/bin/remove-socials`
- `usr/local/bin/add-virtualbox-guest-utils`
- `usr/local/bin/get-chadwm`
- `usr/local/bin/get-sddm-simplicity`
- `usr/local/bin/var`
- `usr/local/bin/fix-sddm-conf`
- `usr/local/bin/sysinfo`
- `usr/local/bin/sysinfo-retro`
- `usr/local/bin/fetch`
- `usr/local/bin/hfetch`
- `usr/local/bin/sfetch`
- `usr/local/bin/pci-latency`
- `CHANGELOG.md`
- `TODO.md` (new stub)
- `IDEAS.md` (new stub)

---

## 2026.05.18

**What Changed**
Added `kiro-verify` — a post-install verification script that checks all configuration settings shipped by this package are actually applied at runtime and scans logs for errors.

**Technical Details**
The script parses `/etc/sysctl.d/99-kiro-optimizations.conf` dynamically (no hardcoded key list) to compare expected vs live values via `sysctl -n`. Additional checks cover: all 34 config files are installed, ZRAM is active with zstd compression, IO schedulers match device type (NVMe→none, SSD→bfq, HDD→mq-deadline), THP settings in `/sys/kernel/mm/`, blacklisted modules not loaded, no failed systemd units, and a journal/udev/dmesg error scan. Outputs PASS/FAIL/WARN/SKIP per check with a final summary, exits 1 on any FAIL. sysctl params missing from the running kernel produce WARN rather than FAIL.

**Files Modified**
- `usr/local/bin/kiro-verify` (new)
- `CHANGELOG.md`

---

## 2026.05.01

**What Changed**
Added CLAUDE.md with architecture overview for Claude Code sessions.

**Technical Details**
Documents the shared library pattern, script conventions, config file map, and current improvement phase status so future sessions don't need to rediscover structure.

**Files Modified**
- `CLAUDE.md` (new)

---

## 2026.04.20

**What Changed**
Phase 1 code quality overhaul: created unified shared library, enabled strict error handling, fixed variable quoting across critical scripts, and standardized logging.

**Technical Details**
- Created `usr/local/lib/kiro-common.sh` (1000+ lines, 80+ functions) consolidating `arcolinux-nemesis/common/common.sh` and EDU-specific utilities into 14 sections
- Removed empty `edu-common.sh` wrapper; all scripts now source `kiro-common.sh` directly
- Enabled `set -Euo pipefail` in all main scripts (previously commented out or absent)
- Fixed 20+ unquoted variable expansions in critical scripts (`edu-fix-pacman-conf`, `get-linux-kiro`, `setup-edu.sh`, `edu-fix-pacman-databases-and-keys`)
- Replaced bare `echo` calls with `log_*` functions throughout
- Added `confirm_destructive_operation()` guards to destructive pacman/key operations
- Added trap-based tmpfile cleanup in repo management scripts
- Replaced hardcoded connectivity checks with `check_connectivity()` library call

**Files Modified**
- `usr/local/lib/kiro-common.sh` (new)
- `usr/local/bin/edu-fix-pacman-conf`
- `usr/local/bin/edu-fix-pacman-databases-and-keys`
- `usr/local/bin/get-linux-kiro`
- `usr/local/bin/add-kiro`
- `usr/local/bin/add-chaotic_repo-to-pacman.conf`
- `usr/local/bin/add-nemesis_repo-to-pacman.conf`
- `usr/local/bin/pac`
- `usr/local/bin/get-me-started`
- `setup-edu.sh`
- `up.sh`

---

## 2026.04.19

**What Changed**
Initial repository setup with system configuration files and utility scripts for Kiro/ArcoLinux desktops.

**Technical Details**
Established the `usr/local/bin/` + `usr/local/lib/` + `etc/` directory tree mirroring the live system layout. Populated with kernel parameter tuning (`sysctl.d`), udev hardware rules, systemd drop-ins, modprobe options, and 40+ utility scripts for pacman, kernel variants, DE fetching, and system info.

**Files Modified**
- Initial commit of all files
