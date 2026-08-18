#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: verify_assets.sh --container-dir DIR --host-index DIR --kraken2-db DIR --kaiju-db DIR [--kaiju-fmi FILE]
USAGE
}

CONTAINER_DIR=""
HOST_INDEX=""
KRAKEN2_DB=""
KAIJU_DB=""
KAIJU_FMI="kaiju_db.fmi"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container-dir) CONTAINER_DIR=$2; shift 2 ;;
        --host-index) HOST_INDEX=$2; shift 2 ;;
        --kraken2-db) KRAKEN2_DB=$2; shift 2 ;;
        --kaiju-db) KAIJU_DB=$2; shift 2 ;;
        --kaiju-fmi) KAIJU_FMI=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

for value in CONTAINER_DIR HOST_INDEX KRAKEN2_DB KAIJU_DB; do
    [[ -n "${!value}" ]] || { echo "Missing required option for $value" >&2; exit 2; }
done

containers=(fastqc.sif fastp.sif star.sif samtools.sif kraken2.sif kaiju.sif python.sif)
for image in "${containers[@]}"; do
    [[ -r "$CONTAINER_DIR/$image" ]] || { echo "Missing container: $CONTAINER_DIR/$image" >&2; exit 1; }
done

[[ -d "$HOST_INDEX" ]] || { echo "Missing host index directory: $HOST_INDEX" >&2; exit 1; }
[[ -r "$HOST_INDEX/Genome" ]] || echo "Warning: $HOST_INDEX/Genome not found; confirm this is a STAR genome index." >&2

[[ -d "$KRAKEN2_DB" ]] || { echo "Missing Kraken2 database: $KRAKEN2_DB" >&2; exit 1; }
[[ -r "$KRAKEN2_DB/hash.k2d" ]] || echo "Warning: hash.k2d not found; confirm Kraken2 DB layout." >&2

[[ -d "$KAIJU_DB" ]] || { echo "Missing Kaiju database: $KAIJU_DB" >&2; exit 1; }
for required in "$KAIJU_FMI" nodes.dmp names.dmp; do
    [[ -r "$KAIJU_DB/$required" ]] || { echo "Missing Kaiju asset: $KAIJU_DB/$required" >&2; exit 1; }
done

echo "All required assets are present."
