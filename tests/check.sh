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
#   Checks the kiro-* scripts and their translations (ROADMAP #16b).
#   Repo mode (default, run by up.sh before every push):
#   - bash -n on every script, no new shellcheck warnings since origin
#   - every script that calls _t/_tf defines it or sources kiro-common.sh,
#     and never before that point; no bare script name sent to gettext
#   - po/kiro-system-files.pot matches the code, every .po passes
#     msgfmt --check, every shipped .mo matches its .po
#   - dry runs in German, Japanese and English (temp copies that use the
#     repo's library and catalogs): translated text appears, no $var is
#     left unfilled; English without gettext; pt/zh sibling fallback;
#     pkexec keeps the language
#   --installed (after the flow): the package ships every .mo, the
#   installed files match the repo, and the installed kiro-skell speaks
#   German.
#
#   Why: the translations live in 16 catalogs and 5 copies of the init
#   block; a text change or a missed make-mo.sh run breaks them silently
#   in every language but English.
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
REPO="$(dirname "$SCRIPT_DIR")"
DOMAIN="kiro-system-files"
LIB="usr/local/lib/kiro-common.sh"
# self-contained scripts: they carry their own copy of the gettext init
SELF_CONTAINED=(kiro-skell kiro-skell-all kiro-audit kiro-calamares-log)
FAILS=0
WARNS=0
TMP=""

pass() { echo "  ${GREEN}PASS${RESET}  $1"; }
fail() { echo "  ${RED}FAIL${RESET}  $1"; FAILS=$((FAILS + 1)); }
warn() { echo "  ${YELLOW}WARN${RESET}  $1"; WARNS=$((WARNS + 1)); }

cleanup() { [[ -n "$TMP" ]] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT

scripts() { find "$REPO/usr/local/bin" -maxdepth 1 -name 'kiro-*' -type f | sort; }

# A generated non-C locale: LANGUAGE is ignored under C/POSIX, so the translated runs need one.
base_locale() { locale -a 2>/dev/null | grep -viE '^(c|c\.utf-?8|posix)$' | head -1; }

# Translate one msgid with the repo's catalogs.
tr_repo() {
    local lang="$1" msg="$2"
    TEXTDOMAINDIR="$REPO/usr/share/locale" LANG="$BASE" LANGUAGE="$lang" gettext -d "$DOMAIN" "$msg"
}

check_syntax() {
    log_section "Syntax and shellcheck"
    local f bad=0
    for f in "$REPO/$LIB" $(scripts) "$REPO/po/make-mo.sh" "$SCRIPT_DIR/check.sh"; do
        bash -n "$f" || { fail "bash -n: ${f#"$REPO"/}"; bad=1; }
    done
    [[ $bad -eq 0 ]] && pass "bash -n on every script"

    if ! command -v shellcheck >/dev/null 2>&1; then
        warn "shellcheck not installed: skipped the warning comparison"
        return 0
    fi
    local base rel old new added total=0
    base="$(git -C "$REPO" rev-parse --verify --quiet '@{upstream}' || git -C "$REPO" rev-parse HEAD)"
    for f in "$REPO/$LIB" $(scripts); do
        rel="${f#"$REPO"/}"
        old="$(git -C "$REPO" show "$base:$rel" 2>/dev/null | shellcheck -S warning -f gcc - 2>/dev/null |
            sed -E 's/^[^:]+:[0-9]+:[0-9]+: //' | sort || true)"
        new="$(shellcheck -S warning -f gcc "$f" 2>/dev/null | sed -E 's/^[^:]+:[0-9]+:[0-9]+: //' | sort || true)"
        added="$(comm -13 <(echo "$old") <(echo "$new") | sed '/^$/d')"
        if [[ -n "$added" ]]; then
            fail "new shellcheck warnings in $rel:"
            sed 's/^/          /' <<<"$added"
            total=1
        fi
    done
    [[ $total -eq 0 ]] && pass "no new shellcheck warnings since ${base:0:7}"
    return 0
}

check_wrapping() {
    log_section "gettext wrapping"
    local f name src first bad=0
    for f in $(scripts); do
        name="$(basename "$f")"
        grep -qE '\$\(_tf? ' "$f" || continue
        if grep -qE '^\s*_t\(\)' "$f"; then
            continue
        fi
        src="$(grep -n "source /usr/local/lib/kiro-common.sh" "$f" | head -1 | cut -d: -f1 || true)"
        if [[ -z "$src" ]]; then
            fail "$name calls _t/_tf but neither defines it nor sources kiro-common.sh"
            bad=1
            continue
        fi
        first="$(grep -nE '\$\(_tf? ' "$f" | head -1 | cut -d: -f1 || true)"
        if (( first < src )); then
            fail "$name calls _t on line $first, before kiro-common.sh is sourced (line $src)"
            bad=1
        fi
    done
    [[ $bad -eq 0 ]] && pass "every script that translates can reach _t/_tf"

    for name in "${SELF_CONTAINED[@]}"; do
        if ! grep -q 'export TEXTDOMAIN=kiro-system-files' "$REPO/usr/local/bin/$name"; then
            fail "$name is self-contained but has no gettext init block"
            bad=1
        fi
    done
    [[ $bad -eq 0 ]] && pass "the ${#SELF_CONTAINED[@]} self-contained scripts carry the init block"

    if grep -qE '^msgid "kiro-[a-z0-9-]+"$' "$REPO/po/$DOMAIN.pot"; then
        fail "a bare script name is sent through gettext: $(grep -oE '^msgid "kiro-[a-z0-9-]+"$' "$REPO/po/$DOMAIN.pot" | head -3 | tr '\n' ' ')"
    else
        pass "no bare script name in the catalog"
    fi
}

# Same extraction as po/make-mo.sh, into a temp file.
fresh_pot() {
    local out="$1"
    (cd "$REPO" && xgettext --language=Desktop --package-name="$DOMAIN" --sort-by-file \
        -o "$TMP/desktop.pot" po/desktop/*.desktop.in 2>/dev/null)
    (cd "$REPO" && xgettext --language=Shell --from-code=UTF-8 --keyword=_t --keyword=_tf \
        --add-comments=Translators: --package-name="$DOMAIN" --sort-by-file \
        -o "$TMP/scripts.pot" "$LIB" usr/local/bin/kiro-*)
    msgcat --use-first -o "$out" "$TMP/desktop.pot" "$TMP/scripts.pot"
}

msgids() { msgcat --no-location --no-wrap --sort-output "$1" | grep -E '^msgid ' | sort; }

check_catalogs() {
    log_section "Catalogs"
    local po lang mo untranslated bad=0
    fresh_pot "$TMP/fresh.pot"
    if diff -q <(msgids "$TMP/fresh.pot") <(msgids "$REPO/po/$DOMAIN.pot") >/dev/null; then
        pass "po/$DOMAIN.pot matches the code"
    else
        fail "po/$DOMAIN.pot is stale: run bash po/make-mo.sh"
        diff <(msgids "$TMP/fresh.pot") <(msgids "$REPO/po/$DOMAIN.pot") | grep '^[<>]' | head -5 | sed 's/^/          /'
    fi

    for po in "$REPO"/po/*.po; do
        lang="$(basename "$po" .po)"
        if ! msgfmt --check -o "$TMP/$lang.mo" "$po" 2>"$TMP/msgfmt.err"; then
            fail "msgfmt --check $lang.po: $(head -2 "$TMP/msgfmt.err" | tr '\n' ' ')"
            bad=1
            continue
        fi
        mo="$REPO/usr/share/locale/$lang/LC_MESSAGES/$DOMAIN.mo"
        if [[ ! -f "$mo" ]]; then
            fail "$lang: no shipped .mo (run bash po/make-mo.sh)"
            bad=1
        elif ! cmp -s "$TMP/$lang.mo" "$mo"; then
            fail "$lang: shipped .mo is older than $lang.po (run bash po/make-mo.sh)"
            bad=1
        fi
    done
    [[ $bad -eq 0 ]] && pass "$(find "$REPO/po" -maxdepth 1 -name '*.po' | wc -l) catalogs pass msgfmt --check and match their .mo"

    # cs, pt, uk carry only the menu entries; the 13 Kiro languages carry the scripts too.
    for lang in de es fr hu it ja nl pl pt_BR ro ru tr zh_CN; do
        # the 4 link-entry URLs stay untranslated on purpose
        untranslated="$(msgattrib --untranslated --no-obsolete "$REPO/po/$lang.po" | grep -E '^msgid "' |
            grep -vE '^msgid "(https?://|")' | wc -l || true)"
        (( untranslated > 0 )) && warn "$lang: $untranslated untranslated string(s), shown in English until translated"
    done
    return 0
}

# Temp copies of the scripts that source the repo's library instead of the installed one.
make_copies() {
    mkdir -p "$TMP/bin" "$TMP/home"
    local f
    for f in $(scripts); do
        sed "s|/usr/local/lib/kiro-common.sh|$REPO/$LIB|g" "$f" > "$TMP/bin/$(basename "$f")"
        chmod +x "$TMP/bin/$(basename "$f")"
    done
}

# run <LANGUAGE or "C"> <script> <args…>: prints the combined output; never fails the check itself.
run() {
    local lang="$1" script="$2"
    shift 2
    if [[ "$lang" == C ]]; then
        env -u LANGUAGE LANG=C LC_ALL=C HOME="$TMP/home" TEXTDOMAINDIR="$REPO/usr/share/locale" \
            bash "$TMP/bin/$script" "$@" 2>&1 || true
    else
        env LANG="$BASE" LANGUAGE="$lang" HOME="$TMP/home" TEXTDOMAINDIR="$REPO/usr/share/locale" \
            bash "$TMP/bin/$script" "$@" 2>&1 || true
    fi
}

# expect <label> <output> <English msgid> <lang>: the translation of msgid must be in the output.
expect() {
    local label="$1" output="$2" msg="$3" lang="$4" want
    want="$(tr_repo "$lang" "$msg")"
    if [[ "$want" == "$msg" ]]; then
        fail "$label: \"$msg\" has no $lang translation"
    elif grep -qF -- "$want" <<<"$output"; then
        pass "$label"
    else
        fail "$label: expected \"$want\""
    fi
}

no_unfilled_vars() {
    local label="$1" output="$2" left
    left="$(grep -oE '\$[A-Za-z_][A-Za-z0-9_]*' <<<"$output" | sort -u | tr '\n' ' ' || true)"
    if [[ -n "$left" ]]; then
        fail "$label: unfilled variable(s) in the output: $left"
    else
        pass "$label: every \$var filled in"
    fi
}

check_runs() {
    log_section "Dry runs (repo library and catalogs)"
    make_copies
    local out lang
    if [[ -z "$BASE" ]]; then
        warn "no generated non-C locale (locale -a): skipped the translated runs"
    else
        for lang in de ja; do
            out="$(run "$lang" kiro-skell --dry-run)"
            expect "kiro-skell --dry-run in $lang" "$out" "Copying /etc/skel to home — be patient" "$lang"
            no_unfilled_vars "kiro-skell --dry-run in $lang" "$out"
            out="$(run "$lang" kiro-skell-all --dry-run)"
            expect "kiro-skell-all --dry-run in $lang" "$out" "Copying /etc/skel to home — be patient" "$lang"
            out="$(run "$lang" kiro-fix-mirrors --no-such-option)"
            expect "kiro-fix-mirrors (kiro-common.sh) in $lang" "$out" "Unknown option:" "$lang"
            out="$(run "$lang" kiro-calamares-log --no-such-option)"
            expect "kiro-calamares-log (own init) in $lang" "$out" "Unknown option:" "$lang"
        done
    fi

    out="$(run C kiro-skell --dry-run)"
    if grep -qF "Copying /etc/skel to home — be patient" <<<"$out" && grep -qF "kiro-skell done" <<<"$out"; then
        pass "kiro-skell --dry-run in English (LANG=C)"
    else
        fail "kiro-skell --dry-run in English (LANG=C) lost its English text"
    fi

    # No gettext on the PATH (ATT's skell copy on a system without it): English, no error, values filled in.
    mkdir -p "$TMP/nogettext"
    local cmd
    for cmd in /usr/bin/*; do
        case "$(basename "$cmd")" in gettext|gettext.sh|envsubst) continue ;; esac
        ln -s "$cmd" "$TMP/nogettext/$(basename "$cmd")"
    done
    out="$(env PATH="$TMP/nogettext" LANG="${BASE:-C}" LANGUAGE=de HOME="$TMP/home" \
        bash "$TMP/bin/kiro-skell" --dry-run 2>&1 || echo "EXIT-FAILED")"
    if grep -qF "kiro-skell done" <<<"$out" && ! grep -qE 'EXIT-FAILED|command not found' <<<"$out"; then
        pass "kiro-skell without gettext: English, no error"
    else
        fail "kiro-skell without gettext: $(grep -E 'EXIT-FAILED|command not found' <<<"$out" | head -2 | tr '\n' ' ')"
    fi
    no_unfilled_vars "kiro-skell without gettext" "$out"

    local got
    got="$(env -u LANGUAGE LANG=pt_PT.UTF-8 bash -c "source '$REPO/$LIB'; echo \"\${LANGUAGE:-unset}\"" 2>/dev/null)"
    [[ "$got" == "pt_PT:pt_BR" ]] && pass "pt_PT falls back to pt_BR (LANGUAGE=$got)" ||
        fail "pt_PT fallback: LANGUAGE=$got, expected pt_PT:pt_BR"
    got="$(env -u LANGUAGE LANG=zh_TW.UTF-8 bash -c "source '$REPO/$LIB'; echo \"\${LANGUAGE:-unset}\"" 2>/dev/null)"
    [[ "$got" == "zh_TW:zh_CN" ]] && pass "zh_TW falls back to zh_CN (LANGUAGE=$got)" ||
        fail "zh_TW fallback: LANGUAGE=$got, expected zh_TW:zh_CN"
    got="$(env -u LANGUAGE LANG=de_DE.UTF-8 bash -c "source '$REPO/$LIB'; echo \"\${LANGUAGE:-unset}\"" 2>/dev/null)"
    [[ "$got" == "unset" ]] && pass "de_DE leaves LANGUAGE alone" || fail "de_DE: LANGUAGE=$got, expected unset"

    got="$(env LANGUAGE=nl LANG="${BASE:-C}" bash -c "source '$REPO/$LIB'; pkexec_env_args | tr '\0' '\n'" 2>/dev/null)"
    if grep -qx 'LANGUAGE=nl' <<<"$got" && grep -q '^PATH=.*/usr/local/bin' <<<"$got"; then
        pass "pkexec re-exec passes the language and /usr/local/bin"
    else
        fail "pkexec_env_args lost LANGUAGE or PATH: $(tr '\n' ' ' <<<"$got")"
    fi
    if grep -q 'env_args+=("${v}=${!v}")' "$REPO/usr/local/bin/kiro-audit"; then
        pass "kiro-audit's own pkexec re-exec passes the language"
    else
        fail "kiro-audit's pkexec re-exec no longer passes LANG/LANGUAGE/LC_*"
    fi
}

check_installed() {
    log_section "Installed package"
    if ! pacman -Q "$DOMAIN" >/dev/null 2>&1; then
        fail "$DOMAIN is not installed"
        return 0
    fi
    log_info "Installed: $(pacman -Q "$DOMAIN")"
    local want have rel bad=0
    want="$(find "$REPO/usr/share/locale" -name "$DOMAIN.mo" | wc -l)"
    have="$(pacman -Qlq "$DOMAIN" | grep -c "/LC_MESSAGES/$DOMAIN.mo$" || true)"
    if [[ "$have" -eq "$want" && "$want" -gt 0 ]]; then
        pass "the package ships all $want catalogs"
    else
        fail "the package ships $have of $want catalogs: rebuild with flow-kiro-system-files"
    fi
    for rel in "$LIB" usr/local/bin/kiro-skell usr/local/bin/kiro-audit usr/share/locale/de/LC_MESSAGES/$DOMAIN.mo; do
        if ! cmp -s "$REPO/$rel" "/$rel"; then
            fail "/$rel differs from the repo: the installed package is older than the code"
            bad=1
        fi
    done
    [[ $bad -eq 0 ]] && pass "installed library, kiro-skell, kiro-audit and the German catalog match the repo"

    if [[ -n "$BASE" ]]; then
        mkdir -p "$TMP/home"
        local out
        out="$(env LANG="$BASE" LANGUAGE=de HOME="$TMP/home" kiro-skell --dry-run 2>&1 || true)"
        expect "installed kiro-skell --dry-run in de" "$out" "Copying /etc/skel to home — be patient" de
    fi
}

#####################################################################
# Main
#####################################################################
main() {
    TMP="$(mktemp -d)"
    BASE="$(base_locale)"
    if [[ "${1:-}" == "--installed" ]]; then
        check_installed
    else
        check_syntax
        check_wrapping
        check_catalogs
        check_runs
    fi
    echo
    if (( FAILS > 0 )); then
        log_error "$FAILS FAIL, $WARNS WARN"
        exit 1
    fi
    log_success "$(basename "$0") done: 0 FAIL, $WARNS WARN"
}

main "$@"
