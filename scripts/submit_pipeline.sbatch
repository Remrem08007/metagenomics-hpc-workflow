#!/usr/bin/env bash
#SBATCH --job-name=meta-nextflow
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=3-00:00:00
#SBATCH --output=metagenomics-nextflow-%j.out
#SBATCH --error=metagenomics-nextflow-%j.err

set -euo pipefail

# SLURM executes a spooled copy of this script, so BASH_SOURCE points into
# /localscratch/spool/... rather than the Git checkout. Resolve the repository
# from an explicit override or from the directory where sbatch was invoked.
SUBMIT_DIR="${SLURM_SUBMIT_DIR:-$PWD}"
REPO_ROOT="${METAGENOMICS_REPO_ROOT:-}"

if [[ -z "$REPO_ROOT" ]]; then
    for candidate in "$SUBMIT_DIR" "$SUBMIT_DIR/.."; do
        if [[ -f "$candidate/main.nf" && -f "$candidate/scripts/run_pipeline.sh" ]]; then
            REPO_ROOT=$(realpath "$candidate")
            break
        fi
    done
fi

if [[ -z "$REPO_ROOT" || ! -f "$REPO_ROOT/main.nf" || ! -f "$REPO_ROOT/scripts/run_pipeline.sh" ]]; then
    echo "Could not locate metagenomics-hpc-workflow repository." >&2
    echo "SLURM submit directory: $SUBMIT_DIR" >&2
    echo "Submit from the repository root, or set METAGENOMICS_REPO_ROOT to the checkout path." >&2
    exit 1
fi

REPO_ROOT=$(realpath "$REPO_ROOT")

# run_pipeline.sh performs its own preflight and, on module-based HPC systems,
# attempts to load Nextflow and Apptainer/Singularity when they are not already
# available in the submitted environment.
exec "$REPO_ROOT/scripts/run_pipeline.sh" --profile slurm "$@"
