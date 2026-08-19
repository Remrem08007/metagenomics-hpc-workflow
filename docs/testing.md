# Testing

The repository has two complementary test layers.

## 1. Deterministic stub test

The CI test uses Nextflow `-stub-run`. It exercises the DSL2 graph, process signatures,
channel wiring, publish paths, and utility scripts without downloading databases or
running bioinformatics containers.

Run it with:

```bash
nextflow run main.nf -profile test -stub-run
```

Exact expected outputs are committed under:

```text
tests/expected/stub/
├── stub.taxonomy_comparison.tsv
├── stub.star_host_depletion_qc.tsv
└── stub.kraken_human_qc.tsv
```

GitHub Actions compares the generated files to these fixtures with `diff -u`.

## 2. Biological mock-community test

A second test runs the real workflow against a deterministic 100-pair mixture.
Pinned RefSeq records or segments are downloaded from NCBI and converted into paired
150 bp reads using a fixed random seed.

The mixture is:

| Source | Source taxid | RefSeq source | Pairs |
| --- | ---: | --- | ---: |
| Homo sapiens GRCh38 chromosome 1 | 9606 | `NC_000001.11:9588911-9614877` | 40 |
| Escherichia coli K-12 MG1655 | 562 | full `NC_000913.3` record | 30 |
| Saccharomyces cerevisiae S288C chromosome I | 4932 | `NC_001133.9:42177-62177` | 20 |
| Influenza A virus A/California/07/2009(H1N1), segment 7 | 11320 | full `NC_026431.1` record | 10 |

The full E. coli chromosome is intentionally used for read generation. A previous
25 kb window (`NC_000913.3:100001-125000`) proved unusually non-discriminative in a
real Kraken2 PlusPF run: nearly all bacterial pairs were assigned only to the
Enterobacteriaceae family. Sampling across the chromosome gives a more representative
species-level smoke test.

Create the mock data with:

```bash
bash scripts/setup_test_data.sh \
  --output-dir "$SCRATCH/metagenomics_test"
```

Use `--force` after changing the fixture definition:

```bash
bash scripts/setup_test_data.sh \
  --output-dir "$SCRATCH/metagenomics_test" \
  --force
```

This creates:

```text
$SCRATCH/metagenomics_test/
├── README.txt
├── references/
│   ├── human.fa
│   ├── ecoli.fa
│   ├── yeast.fa
│   └── influenza_a.fa
└── data/
    ├── mock-community_R1.fastq.gz
    ├── mock-community_R2.fastq.gz
    ├── samplesheet.csv
    ├── ground_truth.tsv
    ├── mixture.tsv
    ├── expected_taxa.tsv
    └── expected_qc.tsv
```

`ground_truth.tsv` records the source, taxid, accession, local position within the
downloaded FASTA sequence, and absolute coordinates on the full RefSeq accession for
every generated read pair. Coordinate columns are 1-based and fragment ends are
inclusive:

```text
source_sequence_start_1based  # local position within the downloaded FASTA
accession_start_1based        # absolute start on the full RefSeq accession
accession_end_1based          # absolute inclusive end on the full RefSeq accession
```

For example, FASTA base 1 of the human test segment corresponds to
`NC_000001.11:9588911`, so a fragment starting at local FASTA position 10,947 starts
at absolute accession position 9,599,857.

### Biological expectations

Unlike the stub fixtures, classifier counts are not required to match an exact
number. Kraken2 and Kaiju use different algorithms and database/taxonomy
representations, so the real-data test checks biologically meaningful invariants.

`tests/expected/biological_expectations.tsv` has classifier-specific taxid columns:

```text
source  name  kraken_taxid  min_kraken_clade_reads  kaiju_taxid  min_kaiju_reads
```

This matters when the same source is normalized differently by the two tools. For the
influenza fixture, Kraken2 reports the current species `Alphainfluenzavirus influenzae`
(taxid `2955291`) while Kaiju's species table may report the historical/child
`Influenza A virus` taxid `11320`. The validator therefore checks those outputs
separately instead of assuming one shared taxid.

The current expectations require:

- E. coli recovered by Kraken2 and Kaiju;
- S. cerevisiae recovered by Kraken2 and Kaiju;
- influenza recovered by Kraken2 at species taxid `2955291` and by Kaiju at taxid
  `11320`;
- STAR residual/unmapped percentage between 45% and 75% for the 40% host / 60%
  non-host mixture;
- residual human abundance in the Kraken2 report between 0% and 5%. A missing human
  node (`NA`, `NOT_FOUND`) is interpreted as 0% residual human for this test.

The checked-in expectation fixtures are:

```text
tests/expected/biological_expectations.tsv
tests/expected/biological_qc_expectations.tsv
```

Kraken2 expectations use species-level **clade reads**, not only direct reads, so a
read assigned to a strain below the expected species still counts as recovery of that
species.

### Run and validate automatically

After containers, the host STAR index and the Kraken2/Kaiju databases are staged:

```bash
bash scripts/run_biological_test.sh \
  --test-dir "$SCRATCH/metagenomics_test" \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk" \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --outdir "$SCRATCH/metagenomics_test_results"
```

Or keep the Nextflow controller off the login node:

```bash
sbatch scripts/submit_biological_test.sbatch \
  --test-dir "$SCRATCH/metagenomics_test" \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk" \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --outdir "$SCRATCH/metagenomics_test_results"
```

The wrapper runs the real pipeline with `-resume` and then calls
`bin/validate_test_run.py`. A successful run ends with:

```text
BIOLOGICAL TEST: PASS
```

If a required taxon disappears, host depletion behaves unexpectedly, or residual
human signal exceeds the allowed test range, the validator exits non-zero.

## Why both test layers exist

The stub test is fast and exact, so it belongs in CI. The biological test is slower
and requires real containers plus large reference databases, but it verifies that the
workflow behaves sensibly on known biological input. Keeping both prevents a pipeline
from being considered healthy merely because its Nextflow graph compiles.
