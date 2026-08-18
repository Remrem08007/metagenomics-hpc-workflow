#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: download_archives.sh --manifest FILE --output-dir DIR

Manifest format (tab-separated):
  filename<TAB>https://example.org/archive.tar.gz

This helper intentionally supports HTTPS downloads only and inherits HTTPS_PROXY/https_proxy.
It downloads files but does not assume a database-specific extraction layout.
USAGE
}

MANIFEST=""
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST=$2; shift 2 ;;
        --output-dir) OUTPUT_DIR=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$MANIFEST" && -n "$OUTPUT_DIR" ]] || { usage >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

while IFS=$'\t' read -r filename url rest; do
    [[ -z "${filename:-}" || "$filename" == \#* ]] && continue
    [[ "$url" == https://* ]] || { echo "Only HTTPS URLs are accepted: $url" >&2; exit 1; }
    dest="$OUTPUT_DIR/$filename"
    if [[ -s "$dest" ]]; then
        echo "Already present: $dest"
        continue
    fi
    curl --fail --location --retry 4 --continue-at - --output "$dest" "$url"
done < "$MANIFEST"
