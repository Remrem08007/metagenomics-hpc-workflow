#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: pull_containers.sh --manifest FILE --output-dir DIR

Manifest format (tab-separated, no header required):
  output_name.sif<TAB>docker://registry/image:tag

The script inherits HTTPS_PROXY/https_proxy from the environment.
Run it before starting the Nextflow workflow. Compute jobs should only use the resulting local .sif files.
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
OUTPUT_DIR=$(realpath -m "$OUTPUT_DIR")

RUNTIME=""
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
    if [[ -r "$dest" ]]; then
        echo "Already present: $dest"
        continue
    fi
    echo "Pulling $uri -> $dest"
    "$RUNTIME" pull "$dest" "$uri"
done < "$MANIFEST"
