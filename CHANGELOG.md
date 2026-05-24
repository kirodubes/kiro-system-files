# CHANGELOG

## 2026.05.24

**What Changed**
- Stopped `62-network-optimization.rules` from emitting two boot-time `ethtool` errors on machines with a consumer Intel NIC (I217/I218/I219, e1000e driver). The rule applied server-NIC tuning knobs to all e1000e devices, which they reject.
- Fixed a false-positive `[FAIL]` in `kiro-verify`: its config-presence list still expected `10-kiro-session.conf` at the old `multi-user.target.wants/systemd-logind.service.d/` path. The drop-in was moved to the canonical `systemd-logind.service.d/` path on 2026.05.22, but the verifier's expected-path list was never updated to match.
- Added graphical privilege escalation: a new `ensure_root()` helper in `kiro-common.sh`, wired into the 5 root-requiring scripts (`kiro-diag`, `kiro-audit`, `kiro-verify`, `kiro-enable-ssh`, `kiro-pci-latency`). Forgetting `sudo` now pops up a polkit password dialog in a graphical session (or falls back to a terminal `sudo` prompt over SSH/tty) instead of erroring out.
- Fixed `kiro-diag` hanging indefinitely at the Bluetooth section when the bluetooth service is inactive.
- Expanded `kiro-audit` to match current config drift: the udev check now validates all 10 shipped rule files (was 2), plus new checks for systemd drop-ins, Intel/Realtek ethernet modprobe configs, and the THP tmpfiles drop-in; help/header text updated for auto-elevation.
- Fixed the ripple from the `pci-latency`→`kiro-pci-latency`, `skel`→`kiro-skel`, `get-nemesis`→`kiro-get-nemesis` script renames: renamed the systemd unit to `kiro-pci-latency.service` (ExecStart, enable symlink, and `kiro-verify`/man-page references all updated), renamed the 3 orphaned man pages, and corrected the README tool table.
- In-depth review of `kiro-verify`: fixed an IO-scheduler false-`FAIL` (it expected `mmcblk` → `bfq`, but `60-io-scheduler.rules` sets non-rotational `mmcblk` → `mq-deadline`), and added the missing `khugepaged/scan_sleep_millisecs=10` THP check. Its 38-entry config-presence list was verified complete and accurate against the shipped tree (no changes).
- In-depth review of `kiro-lint`, two fixes to the udev ATTR-target check: (1) block-device ATTR writes (IO schedulers, read-ahead, fifo_batch — the most common kind) were **never verified**, always `[SKIP]`, because the device-type classifier glob-matched the `KERNEL==` value against case patterns but the value literally contains glob metacharacters (`sd[a-z]*`) and never matched its own pattern — replaced with substring family detection; (2) rules that match by `SUBSYSTEM==` rather than `KERNEL==` (the `power/control` writes in 61-audio-power and 64-gpu) were also skipped — added a subsystem resolver that searches `/sys/bus/<sub>/devices` and `/sys/class/<sub>`. Together these took the verified-write count on a SATA box from 5 → 19 (remaining SKIPs are genuine: no nvme/vd/wifi/backlight present, unloaded modules).

**Technical Details**
- *(ethtool)* The rule lumped `e1000e` together with the server NICs (`igb|ixgbe|i40e`) and assumed shared capabilities. On the I219-V two RUN commands failed every boot: `ethtool -C $name rx-usecs 0 rx-frames 0 tx-usecs 0 tx-frames 0` (exit 1 — consumer e1000e only supports `rx-usecs`, the per-frame/tx knobs return EINVAL) and `ethtool -K $name gso on` (exit 92 — GSO is already on by default and fixed, so setting it returns EOPNOTSUPP).
- *(ethtool)* Split `e1000e` onto its own coalescing line using only the supported `rx-usecs 0`; left the full four-knob line for `igb|ixgbe|i40e`. Dropped `e1000e` from the GSO line entirely. Networking was never affected — this was cosmetic boot-log noise.
- *(kiro-verify)* The expected path was a leftover from the pre-2026.05.22 layout and even contained an impossible drop-in location (`*.target.wants/` holds symlinks, not service override dirs). The file ships and applies correctly on picard (`systemctl show systemd-logind` confirms `TimeoutStopUSec=10s`, `Restart=on-failure`), so this was purely a stale check, not a missing config. Corrected the list entry to `/etc/systemd/system/systemd-logind.service.d/10-kiro-session.conf`.
- Both found via `dmesg`/`journalctl` and `kiro-verify` on picard (bare-metal Kiro v26.05.24), traced to the package with `pacman -Qo`. Shared package, so the fixes improve both the production and `-next` ISOs.
- *(ensure_root)* Re-execs via `exec pkexec env TERM="$TERM" "$self" "$@"` when a display is present and `pkexec` exists, else `exec sudo`. `TERM` is passed through `env` because `pkexec` scrubs the environment, which would otherwise strip colored output. Uses `${BASH_SOURCE[-1]}` so the original script path resolves whether invoked by full path, bare name via `PATH`, or from inside a function. `kiro-audit` is self-contained (does not source `kiro-common.sh`), so it carries its own copy of the helper — must be kept in sync. `--help`/`--version` are handled before `ensure_root`, so they never trigger a password prompt.
- *(kiro-diag)* `bluetoothctl show` blocks on D-Bus when `bluetoothd` is down; it is now skipped entirely when the service is inactive and wrapped in `timeout 3` when active.
- *(kiro-pci-latency.service)* Renamed the unit from `pci-latency.service` to `kiro-pci-latency.service` and repointed `ExecStart` to `/usr/local/bin/kiro-pci-latency` (the old path was deleted by the script rename and would fail `203/EXEC` at boot). Recreated the `multi-user.target.wants/` enable symlink with the corrected `../kiro-pci-latency.service` target, and updated the unit-name references in `kiro-verify` (config list + oneshot result check) and the man pages.
- *(man pages)* Renamed with `git mv` (history preserved); content rewritten with `perl` using a guard that preserves the unchanged `/etc/skel` system path. Service-unit path references were updated to `kiro-pci-latency.service` to match the rename.
- *(kiro-verify)* `check_io_schedulers` expected `mmcblk*` → `bfq`, contradicting `60-io-scheduler.rules`, which groups `mmcblk[0-9]*` with non-rotational `sd*` and sets `mq-deadline`; since eMMC/SD are always non-rotational this was a guaranteed false `FAIL` on any machine with an mmcblk device. Also added a `khugepaged/scan_sleep_millisecs == 10` check (warn-level, mirrors `max_ptes_none`) — the 4th value `thp-tuning.conf` writes but the verifier wasn't checking.
- *(kiro-lint)* `_sysfs_attr_exists` chose its sysfs search base with `case "$kernel_pat" in sd[a-z]*) …`, but `$kernel_pat` holds the literal rule string `sd[a-z]*`, which the glob `sd[a-z]*` cannot match (the `[a-z]` class wants a letter, the string has `[`). So `sd*`/`vd*`/`|`-combined KERNELs fell through to `return 2` (SKIP); only `nvme*n*` matched by accident. Replaced the case with `[[ "$kernel_pat" == *sd* … ]]` substring tests, and dropped a dead `pfx_filter` local. Separately, `check_udev_attr_targets` now also extracts `SUBSYSTEM==` and falls back to a new `_sysfs_subsystem_attr_exists` resolver (searches `/sys/bus/<sub>/devices` then `/sys/class/<sub>`) when a rule has no `KERNEL==`, so the `power/control` / `autosuspend_delay_ms` writes in 61-audio-power and 64-gpu are verified instead of skipped. `KERNEL==` still takes precedence when both are present.

**Files Modified**
- [etc/udev/rules.d/62-network-optimization.rules](etc/udev/rules.d/62-network-optimization.rules)
- [usr/local/bin/kiro-verify](usr/local/bin/kiro-verify)
- [usr/local/lib/kiro-common.sh](usr/local/lib/kiro-common.sh)
- [usr/local/bin/kiro-diag](usr/local/bin/kiro-diag), [usr/local/bin/kiro-audit](usr/local/bin/kiro-audit), [usr/local/bin/kiro-enable-ssh](usr/local/bin/kiro-enable-ssh), [usr/local/bin/kiro-pci-latency](usr/local/bin/kiro-pci-latency), [usr/local/bin/kiro-lint](usr/local/bin/kiro-lint)
- [etc/systemd/system/kiro-pci-latency.service](etc/systemd/system/kiro-pci-latency.service) (renamed from `pci-latency.service`; `multi-user.target.wants/` enable symlink recreated)
- `usr/share/man/man8/{kiro-pci-latency,kiro-skel,kiro-get-nemesis}.8` (renamed from `pci-latency.8`, `skel.8`, `get-nemesis.8`)
- [README.md](README.md)

## 2026.05.22

**What Changed**
Moved the `systemd-logind.service.d/10-kiro-session.conf` drop-in out of `multi-user.target.wants/` to the canonical `systemd-logind.service.d/` path so its settings are actually applied on Kiro installs.

**Technical Details**
- Drop-in was nested at `etc/systemd/system/multi-user.target.wants/systemd-logind.service.d/10-kiro-session.conf`. systemd parses `*.target.wants/` as a list of symlinks-to-units, not a place for service override directories, so it logged at every boot and every `daemon-reload`: `multi-user.target: Wants dependency dropin .../systemd-logind.service.d is not a symlink, ignoring`. The drop-in (`TimeoutStopSec=10s`, `Restart=on-failure`, `RestartSec=5s`, `KillMode=mixed`, `KillSignal=SIGTERM`) was being silently discarded on every install that shipped this package.
- Fix is a pure `git mv` to `etc/systemd/system/systemd-logind.service.d/10-kiro-session.conf` — no content change. Sibling `pci-latency.service` symlink in `multi-user.target.wants/` was already correct and was left in place.
- Found by `journalctl -p err -b` on picard (bare-metal Kiro v26.05.19), then traced to the package via `pacman -Qo`.

**Files Modified**
- `etc/systemd/system/systemd-logind.service.d/10-kiro-session.conf` (moved from `multi-user.target.wants/`)

## 2026.05.21

**What Changed**
Aligned `etc/samba/smb.conf.nemesis` with the personal `arcolinux-nemesis` template. Casing for the Samba share path normalised on the lowercase `Shared` form (was `SHARED`).

**Technical Details**
- `[SAMBASHARE] path = /home/erik/SHARED` → `/home/erik/Shared`; comment header updated to match.
- Decision came out of the HQ cross-stack audit between `arcolinux-nemesis` (personal install scripts) and `edu-system-files` (Kiro block). The two repos shipped functionally identical templates that differed only on casing; `Shared` wins as the canonical form because `arcolinux-nemesis` actively writes `/etc/samba/smb.conf` from its own template on Erik's machines, so aligning here prevents churn.
- The other two collisions found in the audit (zram-generator.conf, 90-memory-accounting.conf) were resolved on the nemesis side by deleting the offending nemesis scripts — `edu-system-files` keeps ownership of those system files unchanged.

**Files Modified**
- [etc/samba/smb.conf.nemesis](etc/samba/smb.conf.nemesis)

## 2026.05.20

**What Changed**
Added the mandatory `Purpose:` / `Why:` header block to 18 scripts in `usr/local/bin/` to bring them in line with the canonical bash template in `~/.claude/CLAUDE.md`.

**Technical Details**
- Inserted a `# Purpose:` prose block (what the script does) followed by a `# Why:` line (motivation) into each script's existing `#####` banner header, between the `DO NOT JUST RUN THIS` warning and the closing banner line.
- No functional code changes — headers only. Existing `set -Euo pipefail`, `SCRIPT_DIR`, sourcing of `kiro-common.sh`, and arg parsing all left untouched.
- `kiro-audit` header refreshed: dropped the old short "verify the install is correct" line and replaced with the full Purpose/Why pair that lists what the audit actually checks (kernel, microcode, mkinitcpio, audio, Calamares cleanup, kiro_final, repos, DEs, SDDM, groups, services, permissions, bootloader, packages).
- Brings these scripts into compliance so anyone opening the file can tell what it does without reading the body — matches the standard set by Kiro-HQ's `up.sh` / `setup.sh` / `cleanup.sh`.

**Files Modified**
- `usr/local/bin/get-nemesis`
- `usr/local/bin/kiro-audit`
- `usr/local/bin/kiro-diag`
- `usr/local/bin/kiro-enable-ssh`
- `usr/local/bin/kiro-fix-gpg-conf`
- `usr/local/bin/kiro-fix-mirrors`
- `usr/local/bin/kiro-fix-pacman-conf`
- `usr/local/bin/kiro-fix-pacman-keys`
- `usr/local/bin/kiro-get-mirrors`
- `usr/local/bin/kiro-install-tools`
- `usr/local/bin/kiro-iso-version`
- `usr/local/bin/kiro-lint`
- `usr/local/bin/kiro-probe`
- `usr/local/bin/kiro-set-cores`
- `usr/local/bin/kiro-verify`
- `usr/local/bin/kiro-which-vga`
- `usr/local/bin/pci-latency`
- `usr/local/bin/skel`

---

## 2026.05.19 (session 5)

**What Changed**
Major expansion of `kiro-diag` with new sections; fixes to `kiro-lint` and `kiro-verify`; stale CUPS check removed from `kiro-audit`.

**Technical Details**
- `kiro-diag` fully rewritten: replaced raw `tput` calls with library color vars, added `_field()` helper, structured into named section functions. New sections: Hardware (CPU, RAM, lsblk), GPU (Intel + AMD + NVIDIA with drivers), Storage (df -h, swap), Network (ip -br), Audio (PipeWire/WirePlumber/PulseAudio via pgrep), Bluetooth (bluez state + adapter), Desktop (DM, WM via pgrep, sessions), Kernel (governor, cmdline), Bootloader (efibootmgr-based detection for systemd-boot/GRUB/rEFInd/Limine), Packages (count, paru/yay status), Temperatures (sensors). System section gained uptime, virtualization, timezone, locale, Kiro package version.
- `kiro-diag` fixes: `log_error` → `echo+RED` for unknown option; NVIDIA driver check now parses `lspci -nnk` directly; nvidia-drm.modeset checks `/proc/cmdline` first then systemd-boot then grub; package version queries installed path not `$BASH_SOURCE`; ISO fields split into release/codename/build; `ohmychadwm` added to WM detection list; Intel GPU detection added.
- `kiro-lint`: fixed `log_error` misuse (ERR trap handler called with plain string); added `w*` to `_sysfs_attr_exists` network branch so `KERNEL=="w*"` udev rules are verified instead of silently skipped.
- `kiro-verify`: corrected IO scheduler expectation for `sd*` SSDs (mq-deadline, not bfq — matches the udev rule); added 3 missing deployed config files to presence check (`dmesg-nopasswd`, `10-kiro-mdns.conf`, `10-kiro-session.conf`).
- `kiro-audit`: removed stale `cups-permissions.conf` tmpfiles.d presence check; simplified CUPS fix branches to always use `chmod 600` directly.

**Files Modified**
- `usr/local/bin/kiro-diag`
- `usr/local/bin/kiro-lint`
- `usr/local/bin/kiro-verify`
- `usr/local/bin/kiro-audit`

---

## 2026.05.19 (session 4)

**What Changed**
Removed the stale `cups-permissions.conf` tmpfiles.d check from `kiro-audit` — the file is no longer deployed on the system.

**Technical Details**
- Dropped the `[[ -f /etc/tmpfiles.d/cups-permissions.conf ]]` presence check that would FAIL if the file was absent.
- Simplified `classes.conf` and `printers.conf` fix branches: removed the conditional that called `systemd-tmpfiles --create`; both now always use `chmod 600` directly.

**Files Modified**
- `usr/local/bin/kiro-audit`

---

## 2026.05.19 (session 3)

**What Changed**
Added `--fix` mode to `kiro-audit` that auto-remediates known fixable failures. Fixed `--version` to read the version from the owning pacman package at runtime instead of a hardcoded string.

**Technical Details**
- `apply_fix "description" cmd [args...]` helper: in `--fix` mode prints the description and runs the command, incrementing `FIXED` on success; in read-only mode prints a `FIX?` hint showing what would run. No `eval` — command and args passed directly via `"$@"`.
- 8 fixable checks wired: 6 archiso leftover file/dir deletions (`10-archiso.conf`, `.automated_script.sh`, `.zlogin`, `getty@tty1` drop-in, `g_wheel`, `49-nopasswd_global.rules`), `systemctl mask pacman-init`, and `systemd-tmpfiles --create` for CUPS permissions (falls back to `chmod 600` if the `tmpfiles.d` conf is absent).
- Summary shows `FIXED: N` when `--fix` is used; final message says "re-run to confirm" rather than hard-failing when fixes were applied — FAIL counter still reflects issues found pre-fix.
- `--version` now runs `pacman -Qqo "$(realpath "${BASH_SOURCE[0]}")"` to get the owning package name, then `pacman -Q "$pkg"` to print `<pkg> <version>`. Falls back gracefully when not installed via pacman.

**Files Modified**
- `usr/local/bin/kiro-audit`

---

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
