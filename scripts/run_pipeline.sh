#!/usr/bin/env bash
set -euo pipefail

INPUT=""
HOST_INDEX=""
KRAKEN2_DB=""
KAIJU_DB=""
KAIJU_FMI=""
CONTAINER_DIR=""
OUTDIR=""
PROFILE="slurm"
ENGINE="auto"
CONFIG=""
WORKDIR=""
MAX_STAR_UNMAPPED_PCT=""
MAX_KRAKEN_HUMAN_PCT=""
CHECK_TOOLS=0

usage() {
  cat <<'USAGE'
Usage:
  run_pipeline.sh \
    --input samplesheet.csv \
    --host-index DIR \
    --kraken2-db DIR \
    --kaiju-db DIR \
    --container-dir DIR \
    --outdir DIR \
    [--kaiju-fmi FILE] \
    [--profile slurm|local] \
    [--engine auto|singularity|apptainer] \
    [--config FILE] \
    [--work-dir DIR] \
    [--max-star-unmapped-pct NUMBER] \
    [--max-kraken-human-pct NUMBER] \
    [--check-tools]

The run is resumable and performs no network downloads.
On module-based HPC systems, missing Nextflow/Apptainer executables are loaded
on a best-effort basis before execution.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT=$2; shift 2 ;;
    --host-index) HOST_INDEX=$2; shift 2 ;;
    --kraken2-db) KRAKEN2_DB=$2; shift 2 ;;
    --kaiju-db) KAIJU_DB=$2; shift 2 ;;
    --kaiju-fmi) KAIJU_FMI=$2; shift 2 ;;
    --container-dir) CONTAINER_DIR=$2; shift 2 ;;
    --outdir) OUTDIR=$2; shift 2 ;;
    --profile) PROFILE=$2; shift 2 ;;
    --engine) ENGINE=$2; shift 2 ;;
    --config) CONFIG=$2; shift 2 ;;
    --work-dir) WORKDIR=$2; shift 2 ;;
    --max-star-unmapped-pct) MAX_STAR_UNMAPPED_PCT=$2; shift 2 ;;
    --max-kraken-human-pct) MAX_KRAKEN_HUMAN_PCT=$2; shift 2 ;;
    --check-tools) CHECK_TOOLS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for name in INPUT HOST_INDEX KRAKEN2_DB KAIJU_DB CONTAINER_DIR OUTDIR; do
  [[ -n "${!name}" ]] || { echo "Missing required argument: $name" >&2; usage >&2; exit 2; }
done
[[ "$PROFILE" == "slurm" || "$PROFILE" == "local" ]] || { echo "--profile must be slurm or local" >&2; exit 2; }
[[ "$ENGINE" =~ ^(auto|singularity|apptainer)$ ]] || { echo "--engine must be auto, singularity or apptainer" >&2; exit 2; }

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/lib/module_utils.sh
source "$REPO_ROOT/scripts/lib/module_utils.sh"

INPUT=$(realpath "$INPUT")
HOST_INDEX=$(realpath "$HOST_INDEX")
KRAKEN2_DB=$(realpath "$KRAKEN2_DB")
KAIJU_DB=$(realpath "$KAIJU_DB")
CONTAINER_DIR=$(realpath "$CONTAINER_DIR")
OUTDIR=$(realpath -m "$OUTDIR")
WORKDIR=${WORKDIR:-"$OUTDIR/work"}
WORKDIR=$(realpath -m "$WORKDIR")

if [[ -n "$CONFIG" ]]; then
  CONFIG=$(realpath "$CONFIG")
  [[ -s "$CONFIG" ]] || { echo "Config not found: $CONFIG" >&2; exit 1; }
fi

try_load_module_for nextflow nextflow || {
  echo "nextflow is not available on PATH and could not be loaded as a module." >&2
  exit 1
}
command -v python3 >/dev/null || { echo "python3 is not available on PATH" >&2; exit 1; }

if [[ "$ENGINE" == "auto" ]]; then
  if try_load_module_for apptainer apptainer; then
    ENGINE=apptainer
  elif try_load_module_for singularity singularity; then
    ENGINE=singularity
  else
    echo "Neither singularity nor apptainer is available on PATH or through modules." >&2
    echo "On Alliance clusters, try: module load apptainer" >&2
    exit 1
  fi
elif ! try_load_module_for "$ENGINE" "$ENGINE"; then
  echo "$ENGINE is not available on PATH and could not be loaded as a module." >&2
  exit 1
fi

python3 "$REPO_ROOT/bin/validate_samplesheet.py" --input "$INPUT"

verify_cmd=(
  "$REPO_ROOT/scripts/verify_assets.sh"
  --container-dir "$CONTAINER_DIR"
  --host-index "$HOST_INDEX"
  --kraken2-db "$KRAKEN2_DB"
  --kaiju-db "$KAIJU_DB"
)
[[ -n "$KAIJU_FMI" ]] && verify_cmd+=(--kaiju-fmi "$KAIJU_FMI")
(( CHECK_TOOLS )) && verify_cmd+=(--check-tools)
"${verify_cmd[@]}"

mkdir -p "$OUTDIR/pipeline_info" "$WORKDIR"

cmd=(nextflow)
[[ -n "$CONFIG" ]] && cmd+=(-c "$CONFIG")
cmd+=(
  run "$REPO_ROOT/main.nf"
  -profile "$PROFILE,$ENGINE"
  -work-dir "$WORKDIR"
  -resume
  --input "$INPUT"
  --host_index "$HOST_INDEX"
  --kraken2_db "$KRAKEN2_DB"
  --kaiju_db "$KAIJU_DB"
  --container_dir "$CONTAINER_DIR"
  --outdir "$OUTDIR"
)
[[ -n "$KAIJU_FMI" ]] && cmd+=(--kaiju_fmi "$KAIJU_FMI")
[[ -n "$MAX_STAR_UNMAPPED_PCT" ]] && cmd+=(--max_star_unmapped_pct "$MAX_STAR_UNMAPPED_PCT")
[[ -n "$MAX_KRAKEN_HUMAN_PCT" ]] && cmd+=(--max_kraken_human_pct "$MAX_KRAKEN_HUMAN_PCT")

{
  printf 'Repository:      %s\n' "$REPO_ROOT"
  printf 'Input:           %s\n' "$INPUT"
  printf 'Profile:         %s\n' "$PROFILE"
  printf 'Engine:          %s\n' "$ENGINE"
  printf 'Host index:      %s\n' "$HOST_INDEX"
  printf 'Kraken2 DB:      %s\n' "$KRAKEN2_DB"
  printf 'Kaiju DB:        %s\n' "$KAIJU_DB"
  printf 'Containers:      %s\n' "$CONTAINER_DIR"
  printf 'Output:          %s\n' "$OUTDIR"
  printf 'Work:            %s\n' "$WORKDIR"
  printf 'Extra config:    %s\n' "${CONFIG:-<none>}"
  printf 'Command:'
  printf ' %q' "${cmd[@]}"
  printf '\n'
} | tee "$OUTDIR/pipeline_info/launch.txt"

"${cmd[@]}"
