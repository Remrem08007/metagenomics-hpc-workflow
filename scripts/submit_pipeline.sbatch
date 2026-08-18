#!/usr/bin/env bash
#SBATCH --job-name=meta-nextflow
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=3-00:00:00
#SBATCH --output=metagenomics-nextflow-%j.out
#SBATCH --error=metagenomics-nextflow-%j.err

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# run_pipeline.sh performs its own preflight and, on module-based HPC systems,
# attempts to load Nextflow and Apptainer/Singularity when they are not already
# available in the submitted environment.
exec "$REPO_ROOT/scripts/run_pipeline.sh" --profile slurm "$@"
