#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=""
FORCE=0

usage() {
    cat <<'USAGE'
Usage: setup_test_data.sh --output-dir DIR [--force]

Creates a deterministic paired-end mock community for a real pipeline smoke test.

The script downloads small pinned RefSeq sequence segments from NCBI over HTTPS,
then generates 100 paired-end reads with fixed composition:

  40 pairs  Homo sapiens GRCh38 chr1   taxid 9606
  30 pairs  Escherichia coli K-12      taxid 562
  20 pairs  Saccharomyces cerevisiae   taxid 4932
  10 pairs  Influenza A virus          taxid 11320

HTTPS_PROXY / https_proxy are inherited automatically.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir) OUTPUT_DIR=$2; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[[ -n "$OUTPUT_DIR" ]] || { usage >&2; exit 2; }

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUTPUT_DIR=$(realpath -m "$OUTPUT_DIR")
REF_DIR="$OUTPUT_DIR/references"
DATA_DIR="$OUTPUT_DIR/data"
mkdir -p "$REF_DIR" "$DATA_DIR"

command -v curl >/dev/null 2>&1 || { echo "curl is required." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required." >&2; exit 1; }

download_ref() {
    local label=$1
    local accession=$2
    local start=$3
    local stop=$4
    local dest="$REF_DIR/${label}.fa"
    local tmp="${dest}.partial"
    local url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=${accession}&rettype=fasta&retmode=text"

    if [[ -n "$start" && -n "$stop" ]]; then
        url="${url}&seq_start=${start}&seq_stop=${stop}"
    fi

    if [[ -s "$dest" && $FORCE -eq 0 ]]; then
        echo "Already present: $dest"
        return
    fi

    echo "Downloading ${label} (${accession}${start:+:${start}-${stop}})"
    rm -f "$tmp"
    curl --fail --location --retry 6 --retry-delay 5 --continue-at - \
        --output "$tmp" "$url"

    grep -q '^>' "$tmp" || {
        echo "Downloaded file is not FASTA: $tmp" >&2
        rm -f "$tmp"
        exit 1
    }
    mv -f "$tmp" "$dest"
}

download_ref human       NC_000001.11 9588911 9614877
download_ref ecoli       NC_000913.3   100001   125000
download_ref yeast       NC_001133.9    42177    62177
download_ref influenza_a NC_026431.1        ""       ""

python3 "$REPO_ROOT/bin/generate_mock_fastqs.py" \
    --source "human,9606,NC_000001.11,$REF_DIR/human.fa,40" \
    --source "ecoli,562,NC_000913.3,$REF_DIR/ecoli.fa,30" \
    --source "yeast,4932,NC_001133.9,$REF_DIR/yeast.fa,20" \
    --source "influenza_a,11320,NC_026431.1,$REF_DIR/influenza_a.fa,10" \
    --output-dir "$DATA_DIR" \
    --sample mock-community \
    --read-length 150 \
    --fragment-length 350 \
    --seed 20260818

cp "$REPO_ROOT/tests/expected/biological_expectations.tsv" "$DATA_DIR/expected_taxa.tsv"
cp "$REPO_ROOT/tests/expected/biological_qc_expectations.tsv" "$DATA_DIR/expected_qc.tsv"

cat > "$OUTPUT_DIR/README.txt" <<EOF
Mock metagenomics test dataset

Samplesheet:
  $DATA_DIR/samplesheet.csv

Ground truth:
  $DATA_DIR/ground_truth.tsv
  $DATA_DIR/mixture.tsv

Expected pipeline results:
  $DATA_DIR/expected_taxa.tsv
  $DATA_DIR/expected_qc.tsv

Reference provenance:
  human       NC_000001.11:9588911-9614877
  ecoli       NC_000913.3:100001-125000
  yeast       NC_001133.9:42177-62177
  influenza_a NC_026431.1 (full record)

The FASTQs are generated deterministically with seed 20260818.
EOF

echo
echo "Test data ready: $OUTPUT_DIR"
echo "Samplesheet:      $DATA_DIR/samplesheet.csv"
echo "Ground truth:     $DATA_DIR/ground_truth.tsv"
echo "Expected taxa:    $DATA_DIR/expected_taxa.tsv"
echo "Expected QC:      $DATA_DIR/expected_qc.tsv"
