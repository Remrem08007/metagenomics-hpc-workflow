#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: pull_containers.sh [--manifest FILE] --output-dir DIR [--force]

Default manifest: assets/containers.tsv
The script inherits HTTPS_PROXY/https_proxy from the environment.
Run this before starting the Nextflow workflow; compute jobs use only the local .sif files.
USAGE
}

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MANIFEST="$REPO_ROOT/assets/containers.tsv"
OUTPUT_DIR=""
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest) MANIFEST=$2; shift 2 ;;
        --output-dir) OUTPUT_DIR=$2; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$OUTPUT_DIR" ]] || { usage >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "Manifest not found: $MANIFEST" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

if command -v apptainer >/dev/null 2>&1; then
    RUNTIME=apptainer
elif command -v singularity >/dev/null 2>&1; then
    RUNTIME=singularity
else
    echo "Neither apptainer nor singularity is available." >&2
    exit 1
fi

while IFS=$'\t' read -r name uri rest; do
    [[ -z "${name:-}" || "$name" == \#* ]] && continue
    [[ -n "${uri:-}" ]] || { echo "Malformed manifest line for $name" >&2; exit 1; }
    [[ "$name" == *.sif ]] || { echo "Container output must end in .sif: $name" >&2; exit 1; }

    dest="$OUTPUT_DIR/$name"
    if [[ -r "$dest" && $FORCE -eq 0 ]]; then
        echo "Already present: $dest"
        continue
    fi

    tmp="${dest%.sif}.partial.sif"
    rm -f "$tmp"
    echo "Pulling $uri -> $dest"
    "$RUNTIME" pull --force "$tmp" "$uri"
    "$RUNTIME" inspect "$tmp" >/dev/null
    mv -f "$tmp" "$dest"
done < "$MANIFEST"

echo "Container preparation complete: $OUTPUT_DIR"
