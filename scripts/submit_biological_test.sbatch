#!/usr/bin/env bash
#SBATCH --job-name=meta-test
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=3-00:00:00
#SBATCH --output=metagenomics-test-%j.out
#SBATCH --error=metagenomics-test-%j.err

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Test data must already exist. This controller performs no downloads; the
# underlying workflow submits its compute-heavy processes through SLURM.
exec bash "$REPO_ROOT/scripts/run_biological_test.sh" --profile slurm "$@"
