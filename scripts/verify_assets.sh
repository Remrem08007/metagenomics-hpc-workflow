#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  verify_assets.sh \
    --container-dir DIR \
    --host-index DIR \
    --kraken2-db DIR \
    --kaiju-db DIR \
    [--kaiju-fmi FILE] \
    [--check-tools]
USAGE
}

CONTAINER_DIR=""
HOST_INDEX=""
KRAKEN2_DB=""
KAIJU_DB=""
KAIJU_FMI=""
CHECK_TOOLS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container-dir) CONTAINER_DIR=$2; shift 2 ;;
        --host-index) HOST_INDEX=$2; shift 2 ;;
        --kraken2-db) KRAKEN2_DB=$2; shift 2 ;;
        --kaiju-db) KAIJU_DB=$2; shift 2 ;;
        --kaiju-fmi) KAIJU_FMI=$2; shift 2 ;;
        --check-tools) CHECK_TOOLS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

for value in CONTAINER_DIR HOST_INDEX KRAKEN2_DB KAIJU_DB; do
    [[ -n "${!value}" ]] || { echo "Missing required option for $value" >&2; exit 2; }
done

CONTAINER_DIR=$(realpath "$CONTAINER_DIR")
HOST_INDEX=$(realpath "$HOST_INDEX")
KRAKEN2_DB=$(realpath "$KRAKEN2_DB")
KAIJU_DB=$(realpath "$KAIJU_DB")

containers=(fastqc.sif fastp.sif star.sif samtools.sif kraken2.sif kaiju.sif python.sif)
for image in "${containers[@]}"; do
    [[ -r "$CONTAINER_DIR/$image" ]] || { echo "Missing container: $CONTAINER_DIR/$image" >&2; exit 1; }
done

for required in Genome SA SAindex; do
    [[ -r "$HOST_INDEX/$required" ]] || { echo "Missing STAR index asset: $HOST_INDEX/$required" >&2; exit 1; }
done

for required in hash.k2d opts.k2d taxo.k2d; do
    [[ -r "$KRAKEN2_DB/$required" ]] || { echo "Missing Kraken2 asset: $KRAKEN2_DB/$required" >&2; exit 1; }
done

for required in nodes.dmp names.dmp; do
    [[ -r "$KAIJU_DB/$required" ]] || { echo "Missing Kaiju asset: $KAIJU_DB/$required" >&2; exit 1; }
done

if [[ -n "$KAIJU_FMI" ]]; then
    [[ -r "$KAIJU_DB/$KAIJU_FMI" ]] || { echo "Missing Kaiju index: $KAIJU_DB/$KAIJU_FMI" >&2; exit 1; }
else
    mapfile -t fmis < <(find "$KAIJU_DB" -maxdepth 1 -type f -name '*.fmi' | sort)
    [[ ${#fmis[@]} -eq 1 ]] || {
        echo "Expected exactly one Kaiju .fmi in $KAIJU_DB; found ${#fmis[@]}. Use --kaiju-fmi." >&2
        exit 1
    }
fi

if (( CHECK_TOOLS )); then
    RUNTIME=""
    if command -v apptainer >/dev/null 2>&1; then
        RUNTIME=apptainer
    elif command -v singularity >/dev/null 2>&1; then
        RUNTIME=singularity
    else
        echo "--check-tools requested but neither apptainer nor singularity is available." >&2
        exit 1
    fi

    declare -A commands=(
        [fastqc.sif]='fastqc --version'
        [fastp.sif]='fastp --version'
        [star.sif]='STAR --version'
        [samtools.sif]='samtools --version'
        [kraken2.sif]='kraken2 --version'
        [kaiju.sif]='command -v kaiju'
        [python.sif]='python3 --version'
    )
    for image in "${containers[@]}"; do
        echo "Checking $image"
        "$RUNTIME" exec "$CONTAINER_DIR/$image" bash -lc "${commands[$image]}" >/dev/null
    done
fi

echo "All required assets are present."
