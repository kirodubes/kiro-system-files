#!/bin/bash
set -euo pipefail
#####################################################################
# Author    : Erik Dubois
# Website   : https://kiroproject.be
#####################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
#   Purpose:
#   - Extract the Name/GenericName/Comment/Keywords of every menu entry
#     in po/desktop/*.desktop.in into po/kiro-system-files.pot.
#   - Merge that template into each po/<lang>.po: a changed English
#     string turns fuzzy, a removed one obsolete.
#   - Write each menu entry into usr/share/applications/ with every
#     language added. Edit the .in files, never usr/share/applications/
#     (those files are overwritten).
#
#   Why: run it after any change to a menu entry, before the flow
#   script builds the package, so the menu shows each user's language.
#
#####################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

#####################################################################
# Colors
#####################################################################
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    CYAN="$(tput setaf 6)"
    RESET="$(tput sgr0)"
else
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" RESET=""
fi

#####################################################################
# Logging
#####################################################################
log_section() {
    echo
    echo "${GREEN}############################################################################${RESET}"
    echo "$1"
    echo "${GREEN}############################################################################${RESET}"
    echo
}

log_info() {
    echo
    echo "${BLUE}############################################################################${RESET}"
    echo "$1"
    echo "${BLUE}############################################################################${RESET}"
    echo
}

log_warn() {
    echo
    echo "${YELLOW}############################################################################${RESET}"
    echo "$1"
    echo "${YELLOW}############################################################################${RESET}"
    echo
}

log_error() {
    echo
    echo "${RED}############################################################################${RESET}"
    echo "$1"
    echo "${RED}############################################################################${RESET}"
    echo
}

log_success() {
    echo
    echo "${GREEN}############################################################################${RESET}"
    echo "$1"
    echo "${GREEN}############################################################################${RESET}"
    echo
}

#####################################################################
# Error handling
#####################################################################
on_error() {
    echo "${RED}ERROR on line $1: $2${RESET}"
    sleep 10
}
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

#####################################################################
# Functions
#####################################################################
DOMAIN="kiro-system-files"
REPO="$(dirname "$SCRIPT_DIR")"
POT="$SCRIPT_DIR/$DOMAIN.pot"
APPS="$REPO/usr/share/applications"

extract() {
    log_section "Extracting the strings into $(basename "$POT")"
    # relative paths only: the source comments in the .pot must not carry a home folder
    (cd "$REPO" && xgettext --language=Desktop --package-name="$DOMAIN" --sort-by-file \
        -o "$POT" po/desktop/*.desktop.in)
    log_info "${CYAN}$(grep -c '^msgid ' "$POT")${RESET} entries (the first is the header)"
}

merge_and_check() {
    local po
    for po in "$SCRIPT_DIR"/*.po; do
        [[ -e "$po" ]] || continue
        log_section "$(basename "$po" .po)"
        msgmerge --quiet --update --backup=none "$po" "$POT"
        # no .mo yet: the menu entries read the .po directly
        msgfmt --check --statistics -o /dev/null "$po"
    done
}

write_desktop() {
    local src
    log_section "Menu entries"
    # msgfmt --desktop reads the languages from po/LINGUAS
    find "$SCRIPT_DIR" -maxdepth 1 -name '*.po' -printf '%f\n' | sed 's/\.po$//' | sort > "$SCRIPT_DIR/LINGUAS"
    for src in "$SCRIPT_DIR"/desktop/*.desktop.in; do
        msgfmt --desktop --template="$src" -d "$SCRIPT_DIR" -o "$APPS/$(basename "$src" .in)"
        log_info "$(basename "$src" .in) written"
    done
}

#####################################################################
# Main
#####################################################################
main() {
    extract
    merge_and_check
    write_desktop
    log_success "$(basename "$0") done"
}

main "$@"
