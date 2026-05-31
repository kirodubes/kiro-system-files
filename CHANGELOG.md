# CHANGELOG

## 2026.05.31

### `kiro-probe` offline save + `kiro-probe-report` HTML insight page

**What Changed**
- `kiro-probe` gains `-s`/`--save [DIR]`: instead of uploading to linux-hardware.org, it saves the probe locally (`hw.info` directory + `hw.info.txz`) and generates a readable HTML insight report from it. This is the offline path — useful when the upload server is down (as happened) or when you just want the data as one local file. Default upload behaviour is unchanged when `--save` is absent.
- New `kiro-probe-report` command turns any saved probe (an `hw.info.txz` archive or `hw.info` directory) into a single self-contained, colour-coded HTML page: system summary cards, a device-status overview (works / detected / failed), a grouped device table, and collapsible raw-log sections (inxi, lscpu, dmidecode, lsblk, smartctl, sensors, glxinfo, lspci, lsusb, nmcli, systemd-analyze, dmesg). Runs without root and contacts no server.

**Technical Details**
- New `usr/local/lib/kiro-probe-report.py` — the HTML generator (the repo's first Python file). Parses the probe's `host` (key:value) and `devices` (`;`-delimited, with a per-device status field) plus selected `logs/`, and emits one dependency-free HTML file with inline CSS. Status colour-codes green/blue/red. Kept as a silent helper invoked by a bash wrapper, so the user-facing layer still sources `kiro-common.sh` per repo convention. `ruff` clean.
- New `usr/local/bin/kiro-probe-report` — bash wrapper (sources `kiro-common.sh`, `--help`/`--version`/`--dry-run`). Resolves a `.txz` (extracted to a temp dir cleaned by an EXIT trap) or a directory to the dir holding `host`, then calls the generator. `chown`s the output back to `$SUDO_USER` when run under sudo.
- Two bugs found and fixed in the wrapper during testing: (1) `resolve_info_dir` originally returned its path via command substitution, so the `WORKDIR` it set lived only in the subshell — the temp dir leaked and parent `WORKDIR` stayed empty. Rewritten to set a global `INFO_DIR` (no subshell). (2) The `cleanup` EXIT-trap function ended on a short-circuited `[[ ... ]] && rm`, returning non-zero when there was nothing to clean; under `set -Euo pipefail` that tripped `kiro-common.sh`'s ERR trap and printed a spurious "ERROR DETECTED" banner (with a misleading stale `BASH_COMMAND`). Added an explicit `return 0`.
- The HTML carries a prominent local-only privacy banner: the raw-log sections embed hardware serial numbers (dmidecode/smartctl/lsblk), so the file is marked do-not-publish.
- New man page `kiro-probe-report.8`; `kiro-probe.8` updated for `--save`. Both lint clean (`groff -man -z`). Verified end-to-end against a real saved probe: both `.txz` and directory inputs render identically (132 KB), bad input exits 1, no temp-dir leak, no spurious ERR banner.

**Files Modified**
- `usr/local/bin/kiro-probe` (added `--save`)
- `usr/local/bin/kiro-probe-report` (new)
- `usr/local/lib/kiro-probe-report.py` (new)
- `usr/share/man/man8/kiro-probe-report.8` (new)
- `usr/share/man/man8/kiro-probe.8` (updated)

### `kiro-audit` — detect virtual machine and close with an anti-panic note

**What Changed**
- `kiro-audit` now detects when it runs inside a virtual machine and ends its output with a clear sentence explaining that the audit is intended for real (bare-metal) hardware, so the expected live-ISO/VM failures (memtest86+ missing files, live-only cleanup checks, etc. — ~22 FAILs on the live ISO) don't read as a broken install. All checks still run; nothing is skipped.
- The run header also gains a `Virt :` line naming the hypervisor (e.g. `oracle` for VirtualBox) when one is detected.

**Technical Details**
- Detection via `systemd-detect-virt --vm --quiet` in `main()` (local `is_vm`/`vm_type`); `|| true` guards the type lookup against the ERR trap. No new dependency — `systemd-detect-virt` ships with systemd.
- The closing banner is emitted as the last output, after the PASS/WARN/FAIL summary and the normal completion banner, so it stays visible even when `exit 1` fires on failures. The summary tail was refactored to compute a local `rc` and `exit "${rc}"` once at the end instead of an inline `exit 1`. `bash -n` clean.
- The closing message is hand-wrapped into short lines (longest ~62 cols) so it fits inside the 76-col banner and the alacritty terminal without wrapping mid-word.
- Verified live on the VirtualBox live-ISO VM (`liveuser`): `systemd-detect-virt` → `oracle`, banner prints after the 22-failure summary.

### Settings Manager entries — Kiro System Audit + System Information (inxi)

**What Changed**
- Two new XFCE Settings Manager launchers so Kiro's system tools are reachable from the graphical Settings dialog, not just the terminal:
  - **Kiro System Audit** → runs `kiro-audit` (Kiro K icon).
  - **System Information** → runs a complete `inxi -Fxxxz` report (familiar from ArcoLinux).
- Both open in **alacritty** (the terminal common to every Kiro environment, not only XFCE) and stay open with a `Press Enter to close...` prompt so the output is readable.

**Technical Details**
- New files `usr/share/applications/kiro-audit.desktop` and `usr/share/applications/kiro-sysinfo.desktop`. Category line `System;Settings;X-XFCE-SettingsDialog;X-XFCE-SystemSettings;` — `X-XFCE-SettingsDialog` is what surfaces them in the Settings Manager, `X-XFCE-SystemSettings` groups them under **System** (without it they land in *Other*).
- Exec uses `alacritty -e bash -c "<cmd>; echo; read -rp 'Press Enter to close...'"` instead of relying on the XFCE terminal helper (`exo-open`): on the live ISO that helper is set to an undefined `custom-TerminalEmulator`, so `Terminal=true` launchers silently fail. Explicit alacritty sidesteps it and works across DEs.
- `inxi -Fxxxz`: `-F` full report, `-xxx` maximum extra data, `-z` filters MAC/IP/identifying data. `inxi` already ships in `archiso/packages.x86_64`.
- Both add `TryExec=` (`kiro-audit` / `inxi`) so the entry auto-hides if the tool is removed.
- Both files pass `desktop-file-validate`; verified live in the Settings Manager under System.

### Settings Manager — surface 5 stock system tools in the System overview

**What Changed**
- Five standard tools that previously lived only in the app menu now also appear in the System group of the Settings Manager, so users get a single "what can I change / what's installed" overview (a deliberate feel-of-control selling point carried over from ArcoLinux). They remain in the app menu exactly as before — these entries are additive, not replacements:
  - **Firewall** (`firewall-config`) — Kiro ships firewalld default-on, so a firewall GUI in System Settings is the most natural fit.
  - **Timeshift** (`timeshift-launcher`) — backups / system restore.
  - **Disks** (`gnome-disks`) — drive / partition / SMART management.
  - **Advanced Network Configuration** (`nm-connection-editor`).
  - **Disk Usage Analyzer** (`baobab`).
- GParted was intentionally left menu-only (destructive root tool — avoid accidental clicks). hardinfo2 left out too (the inxi entry covers system info).

**Technical Details**
- Implemented as same-desktop-ID override copies shipped to `usr/local/share/applications/` (higher XDG_DATA_DIRS precedence than `/usr/share/applications`), so the menu entry stays identical — no duplicate icon — and gains the settings categories. Full upstream files copied verbatim to preserve translations.
- **Two categories are required**, not one: `xfce4-settings-manager` only shows an entry that has **both** the freedesktop `Settings` main category **and** `X-XFCE-SettingsDialog`. `X-XFCE-SettingsDialog` alone is insufficient — this is why Timeshift (`System;` only) and Disks (`...Utility...`) initially did not appear until `Settings;` was added. `X-XFCE-SystemSettings` places them in the **System** group.
- Every override carries `TryExec=<binary>` so that if the user removes the underlying app, the Settings Manager auto-hides the now-dead entry (the shipped `.desktop` is owned by edu-system-files, not the app's package, so it would otherwise persist as a broken icon).
- All five pass `desktop-file-validate`; verified deployed live on the VM.

**Files Modified**
- `usr/local/bin/kiro-audit`
- `usr/share/applications/kiro-audit.desktop` (new)
- `usr/share/applications/kiro-sysinfo.desktop` (new)
- `usr/local/share/applications/firewall-config.desktop` (new)
- `usr/local/share/applications/timeshift-gtk.desktop` (new)
- `usr/local/share/applications/org.gnome.DiskUtility.desktop` (new)
- `usr/local/share/applications/nm-connection-editor.desktop` (new)
- `usr/local/share/applications/org.gnome.baobab.desktop` (new)

## 2026.05.29

### `kiro-audit` — verify cachyos keyring/mirrorlist when `[cachyos]` is active

**What Changed**
- `check_pacman_repos` now goes further when it finds `[cachyos]` uncommented in `pacman.conf`: it confirms `cachyos-keyring` is installed and `/etc/pacman.d/cachyos-mirrorlist` exists. An active cachyos repo without those breaks every pacman sync (signature rejection / missing `Include=` target). This is the verification hook for the new ATT Pacman-page CachyOS toggle, which bootstraps both (bundled packages + `setup-cachyos`, mirroring Chaotic-AUR) before enabling the repo.

**Technical Details**
- Two new checks inside the existing `if grep -q '^\[cachyos\]'` branch: `pkg_installed cachyos-keyring` → PASS/FAIL, and `[[ -f /etc/pacman.d/cachyos-mirrorlist ]]` → PASS/FAIL. The commented-out and absent branches are unchanged (still PASS/WARN — Kiro ships it commented, opt-in). No new `main()` entry; folded into `check_pacman_repos`. `bash -n` clean.

### `kiro-audit` — new `check_chwd` surfaces the Calamares chwd-skip marker

**What Changed**
- New audit section warns when `/var/log/kiro-chwd-skipped.log` exists on the installed system. That marker is written by the Calamares chwd module when `chwd --autoconfigure` could not install the detected driver profile (e.g. a profile package missing from the configured repos), in which case the install now completes on the open driver instead of aborting. Without this check the fallback would be silent — the user would have a working but driver-less system and no signal as to why. Paired with the non-fatal chwd change in [kiro-calamares-config](/home/erik/KIRO/kiro-calamares-config/CHANGELOG.md): that change keeps the install alive, this check makes the skip visible.

**Technical Details**
- WARN (not FAIL): a skipped profile means the system is usable on nouveau/mesa, not broken. The marker body (reason + retry hint) is echoed indented under the WARN line. When no marker exists → PASS (covers both "autoconfigure succeeded" and `driver=free`).
- Section title `chwd driver install`. Called between `check_nvidia` and `check_bootloader` in `main()`. Kernel-agnostic (no kernel-specific paths).
- `bash -n` clean.

**Files Modified**
- `usr/local/bin/kiro-audit`

### `kiro-audit` — `check_pacman_repos` now checks the cachyos opt-in state

**What Changed**
- `check_pacman_repos` gained a cachyos row. Kiro now ships `[cachyos]` commented out in the installed `/etc/pacman.conf` (kiro_final disables it after install — see [kiro-calamares-config](/home/erik/KIRO/kiro-calamares-config/CHANGELOG.md)). The audit reports: PASS when `[cachyos]` is commented (opt-in, as shipped); a soft WARN if it is active (legitimate only if the user re-enabled it on purpose) or absent entirely.

**Technical Details**
- Soft WARN rather than FAIL on an active repo: re-enabling cachyos is a valid user choice, so it must not read as a defect. Matches the existing "intended-state, advisory" tone of the repo checks.
- chaotic-aur remains a FAIL-if-missing check: it is the update source that backs `linux-cachyos` once cachyos is off, so its absence is a real defect.

**Files Modified**
- `usr/local/bin/kiro-audit`

---

## 2026.05.28

### `kiro-audit` — new `check_tuned_profile` for the tuned-ppd pin

**What Changed**
- New audit section asserts `/etc/tuned/ppd_base_profile == performance` and `tuned-adm active == throughput-performance`. Catches the regression where the upstream `tuned` package's pacman install writes `ppd_base_profile=balanced` into the install target, short-circuiting `ppd.conf`'s `default=performance` fallback. Two bare-metal installs (Picard + Riker, both v26.05.28) landed on `balanced` instead of `throughput-performance` — kiro-audit gave 128/0/0 because it had no tuned-side check. This closes the gap so the kiro_final pin (kiro-calamares-config side) is verifiable instead of silent.
- Paired with the kiro_final write in [kiro-calamares-config](/home/erik/KIRO/kiro-calamares-config/CHANGELOG.md) — the write fixes the install, the audit check guarantees we notice if the pin is ever lost again.

**Technical Details**
- Helper handles the "tuned not installed" case (warn, skip), the missing-`tuned-adm`-binary case (warn, skip), and unknown active-profile string (fail with the actual value). Section title `tuned-ppd power profile`. Kernel-agnostic (tuned/tuned-ppd are not kernel-tied).
- Called between `check_resolved_config` and `check_tumbler` in `main()`.
- `bash -n` clean.

**Files Modified**
- `usr/local/bin/kiro-audit`

---

### `show_version` — query pacman at runtime instead of hardcoding

**What Changed**
- `show_version()` in `kiro-common.sh` was printing a hardcoded `version 1.0.0` + frozen `Created: 2026-04-20` line for 17 of the 18 `usr/local/bin/` scripts — directly violating the repo's own "Never hardcode a version string. Query the owning package." rule in CLAUDE.md. Only `kiro-audit` did it correctly (inline). The helper now resolves the caller's path and queries `pacman -Qqo` → `pacman -Q`, so `--version` matches what pacman knows; falls back to `<script> (not installed via pacman)` when run from a source tree. One central fix lifts all 17 scripts at once.

**Technical Details**
- Second parameter to `show_version` is now the script path (defaults to `$0`), so call sites that pass `"$0"` or `"$(basename "$0")"` continue to work; passing `${BASH_SOURCE[0]}` from a caller gives the most accurate resolution under symlinks.
- Uses `realpath` to follow symlinks before the pacman lookup (matches `kiro-audit`'s working pattern).
- `kiro-audit`'s inline `-v|--version` block migrated to call `show_version "$(basename "$0")" "${BASH_SOURCE[0]}"` instead of duplicating the pacman-query pattern. Single source of truth across all 18 scripts now.

**Files Modified**
- `usr/local/lib/kiro-common.sh`
- `usr/local/bin/kiro-audit`

---

### `kiro-audit` is now **kernel-agnostic**

**What Changed**
- `kiro-audit` is now **kernel-agnostic**. It used to hardcode `linux-lqx` in `check_kernel` and `check_mkinitcpio`, so any non-lqx Kiro install (linux-zen / linux-hardened / linux-cachyos / multi-kernel) reported 6 spurious FAILs — proven on a CachyOS install 2026-05-27 (`7.0.10-1-cachyos` installed cleanly, audit FAILed on "expected linux-lqx" + missing lqx vmlinuz/initramfs/packages/preset). Detection now happens at runtime; whatever kernel ships, the audit validates it. Last hardcoded component of the kernel-agnostic set — build-side selector (`kiro-iso-next`) and installer (`kiro_kernel` in `kiro-calamares-config-next`) were already done.

**Technical Details**
- New `detect_kernels()` helper: scans `/usr/lib/modules/*/pkgbase` (every Arch kernel package drops one), emits a sorted/deduped list. Shared by `check_kernel` + `check_mkinitcpio` so both reason from the same source.
- `check_kernel` rewritten: detects installed kernel(s), reports them, then per-kernel loops over `/boot/vmlinuz-${k}`, `/boot/initramfs-${k}.img`, `${k}` package, `${k}-headers`. The running-kernel match is now anchored on `/usr/lib/modules/$(uname -r)/pkgbase` rather than a substring match on `uname -r` — catches the mid-upgrade-before-reboot case as a WARN (not a hard FAIL).
- `check_mkinitcpio` preset block rewritten: per-kernel `${k}.preset` check via the same `detect_kernels`. The stock-`linux.preset`-leftover check is preserved but gated on `! pkg_installed linux` — when `linux` is the chosen kernel, the per-kernel loop covers it and the leftover check is skipped (no double-counting, no false FAIL).
- Man page (`kiro-audit.8`) — kernel section + mkinitcpio bullet rewritten to describe runtime detection; date bumped to 2026-05-28.
- `bash -n` clean. No script structure / template changes — only `check_kernel`, the preset block in `check_mkinitcpio`, and the new helper.

**Files Modified**
- `usr/local/bin/kiro-audit`
- `usr/share/man/man8/kiro-audit.8`

---

### `kiro-enable-ssh`: pacman -Sy + liveuser password on the live ISO

**What Changed**
- `kiro-enable-ssh` now refreshes the pacman database (`pacman -Sy`) before installing openssh — the live ISO's seeded `/var/lib/pacman/sync/` can be empty or stale, so without this the install would fail (or warn loudly).
- On the **live ISO only** (detected via `/run/archiso/bootmnt`), the script now sets `liveuser`'s password to `erik`. Without a password, sshd's password auth refuses the login even after the daemon is up — so the previously-correct opt-in was silently unusable for `liveuser`. The earlier "live sshd is root-only" assumption was wrong: the airootfs `sshd_config.d/10-archiso.conf` permits `PasswordAuthentication yes` + `PermitRootLogin yes` with no `AllowUsers`/`DenyUsers` restriction — the real blocker was just the missing password.

**Technical Details**
- New step ordering in `main()`: refresh pacman db → install openssh → enable sshd → open firewall → set liveuser password (live-ISO-gated).
- `/run/archiso/bootmnt` is the canonical live-ISO marker (archiso always mounts the boot medium there). On an installed system the directory doesn't exist → the password step is a no-op, preserving install-side behaviour.
- The password step uses `bash -c "echo 'liveuser:erik' | chpasswd"` wrapped in `execute_or_dryrun` so `--dry-run` reports the action without making the change.
- Purpose / Why header updated to document both additions.
- `bash -n` clean.

**Files Modified**
- `usr/local/bin/kiro-enable-ssh`

---

### Garuda imports — 5 small tuning adoptions (kernel-agnostic)

**What Changed**
- After comparing edu-system-files against Garuda Mokka's tuning footprint (live ISO over SSH, 2026-05-28), 5 small additions adopted. Everything Garuda ships system-tweaks-wise comes from one tiny package (`garuda-common-settings`); most was already in our set or weaker than ours, but five items were clean wins. Full analysis written to `kiro-iso/docs/garuda-comparison-2026-05-28.md`.
- **New project rule:** every Kiro system tuning addition MUST be kernel-agnostic — works on linux-cachyos (default), linux-zen (fallback), or anything the user pacman-installs later. All 5 adoptions verified against this rule.

**Technical Details**
1. **systemd-oomd** enabled + tuned. Three drop-ins (oomd global + system slice + user slice) plus a `services-systemd.conf` enable line in **both** kiro-calamares-config and kiro-calamares-config-next so the daemon actually runs on installed systems. Policy: `ManagedOOMMemoryPressure=kill` at `80%` pressure for `20s`. Kicks in BEFORE the kernel OOM killer (which only fires when memory is already exhausted), so the desktop stays responsive on 4-8 GiB systems. Not mandatory in services-systemd — kernel OOM is the fallback.
2. **Intel ME blacklist** (`mei`, `mei_me`). Closes a userspace attack surface that has hosted multiple RCE CVEs (e.g. SA-00086). Does not disable ME itself (only BIOS or `me_cleaner` can), only removes the kernel-side hook. AMD machines load nothing here anyway.
3. **`options btusb reset=1`**. Fixes the common "BT works on cold boot, dead after suspend/resume" issue on Intel AX2xx and Realtek RTL8822 combo cards.
4. **Disable kernel zswap** via tmpfile. With zram-generator providing swap, leaving zswap on means double-compression (zswap on cache, then zstd again as it hits zram). Wasted CPU.
5. **NetworkManager `unmanaged-lo`**. Silences the boot-time warning where NM complains about the loopback interface it shouldn't be managing.
- New `check_garuda_imports()` function in `kiro-audit` verifying each file's presence/content + that `systemd-oomd` is enabled, active, mei modules aren't loaded, and zswap reads `0` at runtime. Wired into `main()` between `check_modprobe_thp` and `check_permissions`.
- `--fix` mode added on the systemd-oomd-not-enabled FAIL.
- All file headers cross-reference the analysis doc in kiro-iso so the rationale chain is one click away.
- Companion edit in `CLAUDE.md` records the kernel-agnostic rule under script conventions.
- `bash -n` clean.

**Plus:** removed the `multilib missing from pacman.conf` WARN from `check_pacman_repos`. Multilib is intentionally not shipped (32-bit Wine/Steam libs — not Kiro's target audience); users who want it enable it in one click via ATT. The audit row was noise — silence is the correct signal for a deliberate design choice. Replaced with an inline comment explaining the omission. `syscheck.md` updated to retire the "expected WARN" carve-out.

**Files Modified**
- `etc/systemd/oomd.conf.d/10-kiro-oomd.conf` (new)
- `etc/systemd/system/system.slice.d/10-kiro-oomd-per-slice.conf` (new)
- `etc/systemd/user/slice.d/10-kiro-oomd-per-slice.conf` (new)
- `etc/modprobe.d/blacklist-intel-me.conf` (new)
- `etc/modprobe.d/bluetooth-usb.conf` (new)
- `etc/tmpfiles.d/disable-zswap.conf` (new)
- `etc/NetworkManager/conf.d/unmanaged-lo.conf` (new)
- `usr/local/bin/kiro-audit` (added `check_garuda_imports`)
- `CLAUDE.md` (new "Kernel-agnostic rule" subsection)

Companion changes outside this repo:
- `kiro-calamares-config/etc/calamares/modules/services-systemd.conf` (enable systemd-oomd, non-mandatory)
- `kiro-calamares-config-next/etc/calamares/modules/services-systemd.conf` (same)
- `kiro-iso/docs/garuda-comparison-2026-05-28.md` (new — full analysis)

## 2026.05.26

**What Changed**
- `kiro-audit` now checks that `logrotate.timer` is enabled. Kiro enables it on the installed system via the Calamares `services-systemd` module so file-based logs (`pacman.log`, Xorg/app logs) rotate; journald rotates its own store separately. The audit `WARN`s (not `FAIL`s) when the timer is disabled and offers a `--fix` that runs `systemctl enable logrotate.timer`. `man-db.timer` was reviewed at the same time and intentionally left unchecked — it is not enabled on Kiro (marginal benefit vs periodic wakeup churn).

**Technical Details**
- New block in `check_services()` beside the firewalld check, using the established `pass`/`warn` + `apply_fix` pattern. `is-enabled` is authoritative: a fresh install can read active-but-disabled, which won't persist across reboot. Mirrors the matching checks added the same day to `/syscheck` (item 15) and the ATT Dev page's "System integrity (kiro-audit mirror)" group.

**Files Modified**
- `usr/local/bin/kiro-audit`

## 2026.05.25

**What Changed**
- `kiro-audit` bootloader detection made robust. The UEFI branch now identifies systemd-boot via `bootctl is-installed` (authoritative ESP state) instead of grepping `efibootmgr` for the literal label `Linux Boot Manager`, and the GRUB checks (UEFI and BIOS) now also accept the `grub` package being installed, not just a `/boot/grub` directory. Previously a systemd-boot machine could report `WARN UEFI system but bootloader type unclear` when efibootmgr was unavailable or the firmware entry was relabeled — surfaced on a systemd-boot install during a system audit.

- Removed the dead HDD `fifo_batch` tuning rule from `60-ioschedulers-tuning.rules`. It set `ATTR{queue/iosched/fifo_batch}="32"` on rotating `sd*` disks, but `60-io-scheduler.rules` puts those same disks on BFQ, and BFQ exposes no `fifo_batch` (it is an mq-deadline tunable) — so the write always silently no-oped. This was the `[FAIL]` newly surfaced by the 2026.05.24 kiro-lint block-device ATTR-target fix. Confirmed on the Kiro VB VM: `sda` is `rotational=1` on `[bfq]`, and its `queue/iosched/` dir contains `slice_idle`/`low_latency`/… but no `fifo_batch`.

- Corrected the SSD comment in the same file. It claimed "queue/iosched/ does not exist under mq-deadline so slice_idle_us is unavailable" — both wrong: mq-deadline *does* expose `queue/iosched/` (with `fifo_batch`, `read_expire`, etc.), and `slice_idle_us` is a BFQ tunable, not mq-deadline's. The conclusion (no SSD tuning) was always fine; the reasoning was false. Rewritten to state SSDs run mq-deadline, whose defaults already suit them.

- `kiro-enable-ssh` now opens SSH in the firewall as well as enabling the service. After enabling `sshd` it allows the `ssh` service in firewalld (`firewall-cmd --permanent --add-service=ssh`, then `--reload` if the daemon is running). Previously the script only installed/enabled sshd and silently relied on firewalld's default `public` zone keeping `ssh` open — so on any hardened or non-default zone the "one-command opt-in" would report success yet leave the user unreachable. Discovered while connecting to picard, whose firewalld is active: SSH worked (default zone permits it) but ICMP and mDNS were dropped, so `picard.local` would not resolve and only the LAN IP worked.

**Technical Details**
- The HDD rule's own comment was self-contradictory ("sets HDDs to BFQ, so fifo_batch is available" — BFQ is precisely why it is *not* available). Replaced the rule + comment with a comment documenting why no iosched tuning happens here (HDDs run BFQ, whose defaults already suit mechanical disks). The NVMe `io_poll_delay` rule in the same file is unaffected and still verifies PASS.
- *(kiro-enable-ssh)* The firewall step is guarded by `command -v firewall-cmd` so it is skipped silently when firewalld is not installed, and the `--reload` only runs when `systemctl is-active --quiet firewalld` succeeds (so `--permanent` still writes the config offline if firewalld is stopped). The `--add-service` is idempotent — firewalld returns `ALREADY_ENABLED` (exit 0) when the rule is already present, so it is safe under the script's `set -Euo pipefail` + ERR trap. Header `Purpose`/`Why`, the `--help` description, and the man page (NAME, DESCRIPTION, a new step 3, and a `firewall-cmd(1)` SEE ALSO) were updated to match.

**Files Modified**
- `etc/udev/rules.d/60-ioschedulers-tuning.rules`
- `usr/local/bin/kiro-enable-ssh`
- `usr/share/man/man8/kiro-enable-ssh.8`

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
- Reviewed `kiro-probe` (a thin `hw-probe` upload wrapper — correctly uses per-command `sudo`, no changes beyond the below) and from it caught a systemic bug: `log_error` is the `kiro-common.sh` ERR-trap handler (`log_error <lineno> <cmd>`), but 13 scripts called it with a plain message string, rendering a misleading "⚠️ ERROR DETECTED / Line: <message> / Waiting 10 seconds…" banner (no actual wait) on their error paths. Converted all 15 sites — 12 identical `Unknown option: $arg` arg-parse errors plus 3 bespoke messages (rate-mirrors missing, no-internet, setpci-not-found) — to the `echo "${RED}…${RESET}" >&2` convention already used by kiro-diag/kiro-lint. `kiro-audit` is excluded: it's standalone and its own `log_error` is a message function, so its call is correct.
- Eliminated the *remaining* boot-time `ethtool` error on the `62-network-optimization.rules` e1000e path. Even after the knob-split above (correct single `rx-usecs 0`), the command still failed exit 1 every boot on picard — a separate cause: a udev net-rename race, not an unsupported knob. Fixed by matching the rename `move` event and guarding the call so it can no longer log a failure. Found during a syscheck on picard (booted on the prior package; the split fix removed the EINVAL knobs but not this race).

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
- *(ethtool rename race)* The rule fired on `ACTION=="add"` while the NIC still carried its transient kernel name `eth0`; systemd then renamed it to `enp0s31f6` (a `move` uevent) before udev's queued `ethtool -C eth0 …` exec'd, so the command hit a now-nonexistent `eth0` and exited 1. Confirmed harmless on picard: `ethtool -C enp0s31f6 rx-usecs 0` returns exit 0 and `rx-usecs` is already 0 — pure boot-log noise, networking never affected. Fix: match `ACTION=="add|move"` so the knob is (re)applied against the final renamed name, and wrap each `RUN` in `/bin/sh -c '… || true'` so the racing add-time attempt against the stale name never trips udev's "Process failed" warning. Applied to all three Intel branches (`igb|ixgbe|i40e` coalesce, `e1000e` rx-usecs, `ixgbe|i40e` GSO). The non-Intel branches (r8169 / Broadcom / Mellanox / WiFi) share the same race but no fleet hardware currently exercises them, so they were left unchanged. `udevadm verify` passes on the edited file.

**Files Modified**
- [etc/udev/rules.d/62-network-optimization.rules](etc/udev/rules.d/62-network-optimization.rules)
- [usr/local/bin/kiro-verify](usr/local/bin/kiro-verify)
- [usr/local/lib/kiro-common.sh](usr/local/lib/kiro-common.sh)
- [usr/local/bin/kiro-diag](usr/local/bin/kiro-diag), [usr/local/bin/kiro-audit](usr/local/bin/kiro-audit), [usr/local/bin/kiro-enable-ssh](usr/local/bin/kiro-enable-ssh), [usr/local/bin/kiro-pci-latency](usr/local/bin/kiro-pci-latency), [usr/local/bin/kiro-lint](usr/local/bin/kiro-lint)
- `log_error` sweep: [kiro-probe](usr/local/bin/kiro-probe), [kiro-get-mirrors](usr/local/bin/kiro-get-mirrors), [kiro-fix-mirrors](usr/local/bin/kiro-fix-mirrors), [kiro-which-vga](usr/local/bin/kiro-which-vga), [kiro-fix-pacman-keys](usr/local/bin/kiro-fix-pacman-keys), [kiro-fix-gpg-conf](usr/local/bin/kiro-fix-gpg-conf), [kiro-skel](usr/local/bin/kiro-skel), [kiro-install-tools](usr/local/bin/kiro-install-tools), [kiro-fix-pacman-conf](usr/local/bin/kiro-fix-pacman-conf), [kiro-iso-version](usr/local/bin/kiro-iso-version), [kiro-get-nemesis](usr/local/bin/kiro-get-nemesis), [kiro-set-cores](usr/local/bin/kiro-set-cores) (kiro-enable-ssh, kiro-pci-latency already listed above)
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
