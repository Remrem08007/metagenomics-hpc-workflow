#!/usr/bin/env bash
#SBATCH --job-name=meta-nextflow
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=3-00:00:00
#SBATCH --output=metagenomics-nextflow-%j.out
#SBATCH --error=metagenomics-nextflow-%j.err

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

command -v nextflow >/dev/null || {
  echo "nextflow is not available in the submitted environment." >&2
  echo "Load your Nextflow and Apptainer/Singularity modules before calling sbatch." >&2
  exit 1
}

exec "$REPO_ROOT/scripts/run_pipeline.sh" --profile slurm "$@"
