<p align="center">
  <img src="kiro.jpg" alt="Kiro" width="220" />
</p>

# edu-system-files

System-level files for the Kiro distro — kernel parameters, udev rules, systemd drop-ins, sudoers rules, modprobe blacklists, X11 keyboard maps, sysctl tunings, plus the **`kiro-*` toolchain** of diagnostic and maintenance commands. Owned by Kiro; collisions with personal install scripts (e.g. `arcolinux-nemesis`) are resolved in favour of this repo — see [HQ/ECOSYSTEM.md → cascade rules](../../Insync/Kiro/Kiro-HQ/ECOSYSTEM.md).

## What's in this repo

### `etc/` — system configuration drop-ins
- `sysctl.d/` — kernel tuning (network stack, VM, fs)
- `modprobe.d/` — module options + blacklists
- `udev/` — device rules
- `systemd/` — service drop-ins and timers
- `sudoers.d/` — sudo policy (timestamp_timeout, etc.)
- `security/` — limits.d entries
- `tmpfiles.d/` — runtime tmpfs / cleanup rules
- `samba/` — Samba config including `smb.conf.nemesis` (aligned byte-identical with the `arcolinux-nemesis` personal copy — see [HQ/ECOSYSTEM.md cascade rules](../../Insync/Kiro/Kiro-HQ/ECOSYSTEM.md))
- `pacman.d/`, `X11/` — pacman drop-ins, keyboard layout maps

### `usr/local/bin/` — the `kiro-*` toolchain

| Command                | Purpose                                                                 |
|------------------------|-------------------------------------------------------------------------|
| `kiro-audit`           | Audit a running install against expected Kiro defaults                  |
| `kiro-diag`            | Diagnostic dump: ISO version, BIOS/UEFI, mounts, DM, kernels, NVIDIA    |
| `kiro-enable-ssh`      | Enable + start `sshd.service`                                           |
| `kiro-fix-gpg-conf`    | Reset `/etc/pacman.d/gnupg/` to a clean state                           |
| `kiro-fix-mirrors`     | Repair `/etc/pacman.d/mirrorlist` from a known-good baseline            |
| `kiro-fix-pacman-conf` | Restore Kiro's `pacman.conf` defaults                                   |
| `kiro-fix-pacman-keys` | Re-init + re-populate pacman keyring                                    |
| `kiro-get-mirrors`     | Refresh fast mirror list via reflector                                  |
| `kiro-install-tools`   | Install Kiro's recommended additional packages                          |
| `kiro-iso-version`     | Print `/etc/dev-rel` and rolling-release marker                         |
| `kiro-lint`            | Lint Kiro-specific config files for known anti-patterns                 |
| `kiro-probe`           | Inspect hardware / firmware / driver state                              |
| `kiro-set-cores`       | Set the number of active CPU cores                                      |
| `kiro-verify`          | Post-install verification — does the install match the ISO manifest?    |
| `kiro-which-vga`       | Detect installed VGA card vendor (Intel / AMD / NVIDIA)                 |
| `get-nemesis`          | Helper to fetch the nemesis_repo bootstrap                              |
| `pci-latency`          | One-shot PCI latency tweak                                              |
| `skel`                 | `/etc/skel/` propagation helper                                         |

### `usr/lib/systemd/`, `usr/share/backgrounds/`
Bundled system-wide systemd units and Kiro wallpapers.

## Installation

### From `nemesis_repo` (recommended)

```ini
[nemesis_repo]
SigLevel = Never
Server = https://erikdubois.github.io/$repo/$arch
```

```bash
sudo pacman -Syu
sudo pacman -S edu-system-files
```

This installs the configs into `/etc/` and the `kiro-*` toolchain into `/usr/local/bin/`.

### Manual

```bash
git clone https://github.com/erikdubois/edu-system-files.git
cd edu-system-files
sudo cp -r etc/.   /etc/
sudo cp -r usr/.   /usr/
```

## Related

- [edu-dot-files](https://github.com/erikdubois/edu-dot-files) — user-level dotfiles (companion to this system-level repo).
- [HQ/ECOSYSTEM.md → cascade rules](../../Insync/Kiro/Kiro-HQ/ECOSYSTEM.md) — explicit ownership of paths shared with `arcolinux-nemesis`.

## Websites

Information : https://erikdubois.be

## Social Media

Youtube : https://www.youtube.com/erikdubois

## License

See [LICENSE](./LICENSE).
