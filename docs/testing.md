# Testing and validation

The repository uses two complementary validation layers:

1. a fast deterministic CI/stub layer for workflow structure and output contracts;
2. a committed biological mock-community fixture for end-to-end behavior with real tools and databases.

These tests answer different questions. The stub test asks whether the pipeline is wired correctly and reproducibly. The biological test asks whether the complete workflow behaves sensibly on known sequencing input.

## 1. Deterministic CI / stub test

CI runs Nextflow with `-stub-run`:

```bash
nextflow run main.nf -profile test -stub-run
```

This exercises the DSL2 graph, process signatures, channel wiring, publish paths, utility scripts, and output contracts without downloading databases or executing the bioinformatics containers.

Exact expected outputs are committed under:

```text
tests/expected/stub/
├── stub.taxonomy_comparison.tsv
├── all_samples.taxonomy_comparison.tsv
├── stub.star_host_depletion_qc.tsv
└── stub.kraken_human_qc.tsv
```

GitHub Actions compares these files byte-for-byte with the stub outputs using `diff -u`.

The Python test suite also checks the mock-data generator, classifier-specific biological expectations, coordinate conventions, and the integrity of the committed biological fixture.

## 2. Committed biological mock community

The complete runnable test dataset is committed under:

```text
tests/fixtures/mock-community/
└── data/
    ├── mock-community_R1.fastq.gz
    ├── mock-community_R2.fastq.gz
    ├── samplesheet.csv
    ├── ground_truth.tsv
    ├── mixture.tsv
    ├── expected_taxa.tsv
    └── expected_qc.tsv
```

The FASTQs contain exactly **100 paired-end fragments**, each with 150 bp reads and a 350 bp source fragment.

| Source | Source taxid | RefSeq source | Pairs |
| --- | ---: | --- | ---: |
| Homo sapiens GRCh38 chromosome 1 | 9606 | `NC_000001.11:9588911-9614877` | 40 |
| Escherichia coli K-12 MG1655 | 562 | full `NC_000913.3` record | 30 |
| Saccharomyces cerevisiae S288C chromosome I | 4932 | `NC_001133.9:42177-62177` | 20 |
| Influenza A virus A/California/07/2009(H1N1), segment 7 | 11320 | full `NC_026431.1` record | 10 |

The fixture was generated with seed `20260818`. The gzip streams are deterministic (`mtime=0`), so regenerating from the same reference records and code yields reproducible read content.

### Ground truth

`ground_truth.tsv` contains one row per read pair with:

```text
pair_id
source
taxid
accession
source_sequence_start_1based
accession_start_1based
accession_end_1based
fragment_length
```

Coordinates are explicit:

- `source_sequence_start_1based` is the local position within the downloaded FASTA sequence;
- `accession_start_1based` is the position on the full RefSeq accession;
- `accession_end_1based` is the inclusive fragment end on the full accession.

For the human source, FASTA base 1 corresponds to `NC_000001.11:9588911`.

### Portable samplesheet

The committed `samplesheet.csv` uses paths relative to the fixture directory:

```csv
sample,fastq_1,fastq_2
mock-community,mock-community_R1.fastq.gz,mock-community_R2.fastq.gz
```

The pipeline resolves relative FASTQ paths relative to the samplesheet itself, so the fixture remains portable after cloning the repository.

## Biological expectations

The biological test checks **known-source recovery and QC invariants**, not exact per-read species classification.

That distinction is important: short reads may be correctly recognized at family or genus level when they do not contain enough unique sequence to support a species-level assignment. The smoke test therefore verifies pipeline behavior without claiming that all reads must resolve to the most specific possible taxon.

The expectation schema is:

```text
source  name  kraken_taxid  min_kraken_clade_reads  kaiju_taxid  min_kaiju_reads
```

Kraken2 and Kaiju are evaluated independently because their database structures and taxonomy representations can differ.

Current expectations are stored in:

```text
tests/expected/biological_expectations.tsv
tests/expected/biological_qc_expectations.tsv
```

and copied into the committed fixture.

### Classifier-specific taxonomy

For influenza, the two tools legitimately report different taxonomic nodes:

- Kraken2 species row: `2955291` — `Alphainfluenzavirus influenzae`;
- Kaiju species summary: `11320` — `Influenza A virus`.

The validator checks each classifier against its expected taxid instead of forcing both outputs onto one identifier.

For Kraken2, the test uses **clade reads**, not only direct taxon reads. A read classified below the species node therefore contributes to the species clade count, which is the appropriate species-level recovery measure for the Kraken report.

### Host-depletion QC

The fixture contains 40 host pairs and 60 non-host pairs. The checked QC invariants are:

- STAR residual percentage between 45% and 75%;
- Kraken2 residual human abundance between 0% and 5%.

A missing human node in the Kraken2 report (`NA` / `NOT_FOUND`) is interpreted as 0% residual human for this smoke test.

## Validated end-to-end behavior

A full SLURM run of the committed biological design completed all pipeline processes and returned:

```text
BIOLOGICAL TEST: PASS
```

The reference run produced:

- STAR residual fraction: **60.0000%**, exactly matching the designed 40% host / 60% non-host mixture;
- Kraken2 human taxid `9606`: **not found** after host depletion;
- expected E. coli signal recovered by both classifiers;
- all 20 yeast-derived pairs represented in the Kraken2 S. cerevisiae clade;
- all 10 influenza-derived pairs represented in the Kraken2 influenza species clade and recovered in the Kaiju influenza summary.

Species-level resolution is intentionally not presented as a universal accuracy benchmark. For example, many short E. coli-derived fragments can resolve only to Enterobacteriaceae or Escherichia in Kraken2 while still remaining in the correct broader lineage. The purpose of this fixture is to detect broken workflow behavior, not to overstate taxonomic resolution.

## Run the committed fixture

After staging a host STAR index, Kraken2 database, Kaiju database, and local containers:

```bash
bash scripts/run_biological_test.sh \
  --test-dir "$PWD/tests/fixtures/mock-community" \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk \
  --container-dir /shared/metagenomics/containers \
  --outdir /shared/results/metagenomics-smoke-test \
  --profile slurm
```

The wrapper runs the normal workflow with `-resume` and then invokes `bin/validate_test_run.py`.

## Regenerate the fixture from public references

The committed reads can be reproduced from the pinned RefSeq sources:

```bash
bash scripts/setup_test_data.sh \
  --output-dir /shared/metagenomics/generated-test-data \
  --force
```

This provisioning step requires HTTPS access to NCBI. It is separate from the analysis workflow so restricted compute nodes do not need network access.

The generator also writes the same ground-truth and mixture metadata used to create the committed fixture.

## Why both layers exist

A compiling Nextflow graph is not enough evidence that a bioinformatics pipeline is healthy, while a full biological run is too expensive and environment-dependent for every CI invocation.

The combination provides both:

- **fast regression protection** through exact CI/stub outputs;
- **biological confidence** through a transparent, known-source end-to-end fixture.
