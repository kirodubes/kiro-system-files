# IDEAS

## Backlog

## Claude's Ideashop

**Static config linter for `etc/` files**
Add a `kiro-lint` script that statically analyses the `etc/` directory before deployment: checks for duplicate sysctl keys within the same file, verifies udev `ATTR{}` writes reference known sysfs paths, cross-checks modprobe.d parameters against the actual loaded driver's `/sys/module/*/parameters/`, and flags conflicting settings across files (e.g. power_save in both modprobe.d and a udev rule). Rationale: the audit this session found 23 issues — a linter would have caught most of them automatically before they ever shipped to users.
