# TODO

## In Progress

## Planned

### kiro-lint — static config analyser
- Check `etc/sysctl.d/` files for duplicate keys within the same file
- Cross-check `modprobe.d/` parameters against `/sys/module/<driver>/parameters/` on the running system
- Flag conflicting settings across files (e.g. `power_save` set in both modprobe.d and a udev rule)
- Verify udev `ATTR{}` write targets exist in sysfs before deployment

### Phase 2 — Script flags
- Add `--help` and `--dry-run` to all `usr/local/bin/` scripts

### Phase 3 — Config files
- Externalize hardcoded values into config files

### Phase 4 — Quality pass
- Full shellcheck + shfmt pass on all scripts

## Done
- Phase 1: unified library, error handling, variable quoting (2026.04.20)
- kiro-verify post-install verification script (2026.05.18)
