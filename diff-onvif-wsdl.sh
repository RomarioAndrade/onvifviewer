#!/usr/bin/env bash
#
# diff-onvif-wsdl.sh
#
# Downloads the current upstream versions of the ONVIF WSDL/XSD files that
# libOnvifConnect actually compiles (see libOnvifConnect/CMakeLists.txt) and
# diffs them against the local copies in 3rdparty/wsdl/.
#
# It does NOT modify the working tree: everything is fetched into a temp dir
# and compared read-only. Review the diffs, then update by hand if wanted.
#
# Usage:
#   ./diff-onvif-wsdl.sh            # diff to stdout
#   ./diff-onvif-wsdl.sh -o out/   # also save each remote file + .diff into out/
#
# Copyright (C) 2026
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

# --- config -----------------------------------------------------------------

# Repo-relative root that mirrors the ONVIF URL layout (…/www.onvif.org/<path>).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ROOT="$SCRIPT_DIR/3rdparty/wsdl/www.onvif.org"
BASE_URL="https://www.onvif.org"

# The six files that matter, expressed as paths relative to www.onvif.org/.
# The local directory layout is an exact mirror of the upstream URL path,
# so the same relative path works for both the file on disk and the URL.
FILES=(
    "ver10/device/wsdl/devicemgmt.wsdl"
    "ver10/media/wsdl/media.wsdl"
    "ver20/media/wsdl/media2.wsdl"
    "ver20/ptz/wsdl/ptz.wsdl"
    "ver10/schema/onvif.xsd"
    "ver10/schema/common.xsd"
)

# Files known to be locally patched (diff will include our own edits as noise).
PATCHED=(
    "ver20/media/wsdl/media2.wsdl"
)

# Local path -> upstream URL path, for files whose local name/location differs
# from ONVIF's. The Media2 service WSDL is renamed locally (see the TODO in
# libOnvifConnect/CMakeLists.txt): upstream it is ver20/media/wsdl/media.wsdl.
declare -A URL_OVERRIDE=(
    ["ver20/media/wsdl/media2.wsdl"]="ver20/media/wsdl/media.wsdl"
)

# --- args -------------------------------------------------------------------

OUT_DIR=""
while getopts ":o:h" opt; do
    case "$opt" in
        o) OUT_DIR="$OPTARG" ;;
        h) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Unknown option. Use -h for help." >&2; exit 2 ;;
    esac
done

command -v curl >/dev/null || { echo "error: curl not found" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ -n "$OUT_DIR" ]; then
    mkdir -p "$OUT_DIR"
fi

# --- helpers ----------------------------------------------------------------

# Pull the schema/definitions version="XX.YY" attribute from a file, if present.
declared_version() {
    grep -oE 'version="[0-9]{2}\.[0-9]{2}"' "$1" 2>/dev/null | head -n1 | sed 's/version=//; s/"//g' || true
}

is_patched() {
    local f="$1"
    for p in "${PATCHED[@]}"; do
        [ "$p" = "$f" ] && return 0
    done
    return 1
}

# --- main -------------------------------------------------------------------

changed=0
unreachable=0

printf '%-45s %-8s %-8s %s\n' "FILE" "LOCAL" "REMOTE" "STATUS"
printf '%-45s %-8s %-8s %s\n' "----" "-----" "------" "------"

for rel in "${FILES[@]}"; do
    local_file="$LOCAL_ROOT/$rel"
    remote_file="$TMP_DIR/$rel"
    url="$BASE_URL/${URL_OVERRIDE[$rel]:-$rel}"

    mkdir -p "$(dirname "$remote_file")"

    if [ ! -f "$local_file" ]; then
        printf '%-45s %-8s %-8s %s\n' "$rel" "MISSING" "-" "local file not found"
        continue
    fi

    if ! curl -fsSL --retry 2 --connect-timeout 15 "$url" -o "$remote_file"; then
        printf '%-45s %-8s %-8s %s\n' "$rel" "$(declared_version "$local_file")" "-" "DOWNLOAD FAILED ($url)"
        unreachable=$((unreachable + 1))
        continue
    fi

    lv="$(declared_version "$local_file")"
    rv="$(declared_version "$remote_file")"

    note=""
    is_patched "$rel" && note=" [locally patched]"

    if diff -q "$local_file" "$remote_file" >/dev/null 2>&1; then
        printf '%-45s %-8s %-8s %s\n' "$rel" "${lv:-?}" "${rv:-?}" "identical$note"
    else
        printf '%-45s %-8s %-8s %s\n' "$rel" "${lv:-?}" "${rv:-?}" "DIFFERS$note"
        changed=$((changed + 1))
    fi

    if [ -n "$OUT_DIR" ]; then
        mkdir -p "$OUT_DIR/$(dirname "$rel")"
        cp "$remote_file" "$OUT_DIR/$rel.remote"
        diff -u "$local_file" "$remote_file" > "$OUT_DIR/$rel.diff" 2>/dev/null || true
    fi
done

echo
echo "======================================================================"
echo " Unified diffs (local vs. upstream)"
echo "======================================================================"

for rel in "${FILES[@]}"; do
    local_file="$LOCAL_ROOT/$rel"
    remote_file="$TMP_DIR/$rel"
    [ -f "$local_file" ] && [ -f "$remote_file" ] || continue

    if ! diff -q "$local_file" "$remote_file" >/dev/null 2>&1; then
        echo
        echo "----- $rel -----"
        is_patched "$rel" && echo "(NOTE: this file is patched locally; part of this diff is our own edit)"
        diff -u "$local_file" "$remote_file" || true
    fi
done

echo
echo "Summary: $changed file(s) differ, $unreachable download failure(s)."
[ -n "$OUT_DIR" ] && echo "Remote copies and per-file .diff saved under: $OUT_DIR"
echo "No local files were modified."
