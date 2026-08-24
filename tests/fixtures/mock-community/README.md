# Mock-community biological fixture

This directory contains the complete, runnable paired-end input fixture used by the repository's end-to-end biological smoke test.

## Contents

```text
data/
├── mock-community_R1.fastq.gz
├── mock-community_R2.fastq.gz
├── samplesheet.csv
├── ground_truth.tsv
├── mixture.tsv
├── expected_taxa.tsv
└── expected_qc.tsv
```

The FASTQs contain 100 deterministic read pairs:

| Source | RefSeq source | Pairs |
| --- | --- | ---: |
| Human GRCh38 chromosome 1 | `NC_000001.11:9588911-9614877` | 40 |
| Escherichia coli K-12 MG1655 | full `NC_000913.3` | 30 |
| Saccharomyces cerevisiae chromosome I | `NC_001133.9:42177-62177` | 20 |
| Influenza A virus A/California/07/2009(H1N1), segment 7 | full `NC_026431.1` | 10 |

Reads are 150 bp from 350 bp fragments and were generated with seed `20260818`. `ground_truth.tsv` records the source and full-accession coordinates for every pair.

The committed `samplesheet.csv` uses relative paths, so it works from any clone of the repository.

## Run

After staging a host STAR index, Kraken2 database, Kaiju database, and the local containers:

```bash
bash scripts/run_biological_test.sh \
  --test-dir "$PWD/tests/fixtures/mock-community" \
  --host-index /path/to/host_STAR_index \
  --kraken2-db /path/to/kraken2_db \
  --kaiju-db /path/to/kaiju_db \
  --container-dir /path/to/containers \
  --outdir /path/to/test_results
```

A successful end-to-end run finishes with:

```text
BIOLOGICAL TEST: PASS
```

## Reproduction

The fixture can be regenerated from the pinned public RefSeq sources with:

```bash
bash scripts/setup_test_data.sh \
  --output-dir /path/to/generated_test_data \
  --force
```

Reference FASTA files are not vendored here because they are only provenance inputs used to generate the small committed FASTQ fixture; they are not required to run the test.

See `docs/testing.md` for validation semantics and the distinction between smoke-test recovery and exact species-level classification accuracy.
