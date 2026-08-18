#!/usr/bin/env bash
set -euo pipefail

TEST_DIR=""
HOST_INDEX=""
KRAKEN2_DB=""
KAIJU_DB=""
CONTAINER_DIR=""
OUTDIR=""
PROFILE="slurm"
ENGINE="auto"
CONFIG=""
WORKDIR=""
KAIJU_FMI=""

usage() {
    cat <<'USAGE'
Usage:
  run_biological_test.sh \
    --test-dir DIR \
    --host-index DIR \
    --kraken2-db DIR \
    --kaiju-db DIR \
    --container-dir DIR \
    --outdir DIR \
    [--kaiju-fmi FILE] \
    [--profile slurm|local] \
    [--engine auto|singularity|apptainer] \
    [--config FILE] \
    [--work-dir DIR]

TEST_DIR must have been created by scripts/setup_test_data.sh.

The script runs the real workflow with containers and databases, then checks the
observed taxonomy and host-depletion QC against the bundled biological expectations.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --test-dir) TEST_DIR=$2; shift 2 ;;
        --host-index) HOST_INDEX=$2; shift 2 ;;
        --kraken2-db) KRAKEN2_DB=$2; shift 2 ;;
        --kaiju-db) KAIJU_DB=$2; shift 2 ;;
        --container-dir) CONTAINER_DIR=$2; shift 2 ;;
        --outdir) OUTDIR=$2; shift 2 ;;
        --kaiju-fmi) KAIJU_FMI=$2; shift 2 ;;
        --profile) PROFILE=$2; shift 2 ;;
        --engine) ENGINE=$2; shift 2 ;;
        --config) CONFIG=$2; shift 2 ;;
        --work-dir) WORKDIR=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

for name in TEST_DIR HOST_INDEX KRAKEN2_DB KAIJU_DB CONTAINER_DIR OUTDIR; do
    [[ -n "${!name}" ]] || {
        echo "Missing required argument: $name" >&2
        usage >&2
        exit 2
    }
done

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(realpath "$TEST_DIR")
SAMPLESHEET="$TEST_DIR/data/samplesheet.csv"
EXPECTED="$TEST_DIR/data/expected_taxa.tsv"
EXPECTED_QC="$TEST_DIR/data/expected_qc.tsv"

[[ -s "$SAMPLESHEET" ]] || { echo "Missing test samplesheet: $SAMPLESHEET" >&2; exit 1; }
[[ -s "$EXPECTED" ]] || { echo "Missing expected taxa file: $EXPECTED" >&2; exit 1; }
[[ -s "$EXPECTED_QC" ]] || { echo "Missing expected QC file: $EXPECTED_QC" >&2; exit 1; }

cmd=(
    "$REPO_ROOT/scripts/run_pipeline.sh"
    --input "$SAMPLESHEET"
    --host-index "$HOST_INDEX"
    --kraken2-db "$KRAKEN2_DB"
    --kaiju-db "$KAIJU_DB"
    --container-dir "$CONTAINER_DIR"
    --outdir "$OUTDIR"
    --profile "$PROFILE"
    --engine "$ENGINE"
)
[[ -n "$KAIJU_FMI" ]] && cmd+=(--kaiju-fmi "$KAIJU_FMI")
[[ -n "$CONFIG" ]] && cmd+=(--config "$CONFIG")
[[ -n "$WORKDIR" ]] && cmd+=(--work-dir "$WORKDIR")

"${cmd[@]}"

python3 "$REPO_ROOT/bin/validate_test_run.py" \
    --results "$OUTDIR" \
    --expected "$EXPECTED" \
    --expected-qc "$EXPECTED_QC" \
    --sample mock-community
