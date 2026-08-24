# Metagenomics HPC Workflow

[![CI](https://github.com/Remrem08007/metagenomics-hpc-workflow/actions/workflows/ci.yml/badge.svg)](https://github.com/Remrem08007/metagenomics-hpc-workflow/actions/workflows/ci.yml)

A reusable **Nextflow DSL2** workflow for paired-end sequencing data that performs read QC, trimming, sensitive host depletion, and complementary nucleotide- and protein-level taxonomic classification with **Kraken2** and **Kaiju**.

The workflow is designed for research HPC systems, including clusters where SLURM compute nodes have **no direct internet access**. Containers, databases, and reference indexes are provisioned separately; analysis uses only local files and pre-staged assets.

The repository includes a **committed, deterministic 100-pair biological mock community** with FASTQs, per-pair ground truth, expected taxa, and expected QC ranges. The complete workflow has been validated end-to-end on SLURM with this fixture and returns `BIOLOGICAL TEST: PASS`.

## Workflow

```text
paired FASTQ
    |
    +-- FastQC
    |
    +-- fastp trimming
            |
            +-- STAR host alignment
                    |
                    +-- samtools: retain pairs where BOTH mates are unmapped
                            |
                            +-- host-depletion QC
                            |
                            +-------------------+
                            |                   |
                            v                   v
                         Kraken2              Kaiju
                        nucleotide            protein
                            |                   |
                            +---------+---------+
                                      |
                                      v
                         per-sample comparison
                                      |
                                      v
                         combined taxonomy table
```

Kraken2 and Kaiju evidence is reported **side-by-side and never summed**. The tools use different search strategies and may represent the same biological source at different taxonomic nodes, so classifier-specific taxids are preserved.

## Highlights

- paired-end FASTQ input;
- FastQC and configurable fastp preprocessing;
- splice-aware STAR host subtraction;
- strict non-host extraction requiring **both mates** to be unmapped;
- secondary/supplementary alignments excluded during non-host extraction;
- Kraken2 paired nucleotide classification;
- Kaiju paired protein-level classification;
- host-depletion and residual-human QC tables with optional thresholds;
- classifier evidence kept separate in merged taxonomic tables;
- local Apptainer/Singularity images during analysis;
- large reference databases used directly from shared storage;
- `local` and `slurm` execution profiles;
- resumable execution with `-resume`;
- offline-friendly Nextflow launcher behavior;
- deterministic unit/stub tests plus a real biological smoke test;
- no lab-specific paths, sample conventions, account IDs, or study-specific interpretation logic.

## Reproducible biological fixture

The runnable fixture is committed under:

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

The 100 paired-end fragments are generated deterministically from pinned public RefSeq sources:

| Source | Source taxid | RefSeq source | Pairs |
| --- | ---: | --- | ---: |
| Human GRCh38 chromosome 1 | 9606 | `NC_000001.11:9588911-9614877` | 40 |
| *Escherichia coli* K-12 MG1655 | 562 | full `NC_000913.3` | 30 |
| *Saccharomyces cerevisiae* chromosome I | 4932 | `NC_001133.9:42177-62177` | 20 |
| Influenza A virus A/California/07/2009(H1N1), segment 7 | 11320 | full `NC_026431.1` | 10 |

Because the FASTQs are committed, running the biological fixture does **not** require downloading test reads. `scripts/setup_test_data.sh` remains available to reproduce the fixture from its public reference provenance and fixed seed.

### What the biological test validates

The smoke test verifies that the workflow behaves correctly end-to-end rather than demanding that every short read be classified to an exact species. It checks that:

- the known host/non-host mixture is handled correctly by STAR;
- expected non-human sources are recovered by Kraken2 and Kaiju;
- classifier-specific taxonomy is handled correctly (for example influenza taxonomy differs between the two tools);
- residual human signal remains within the configured test range;
- the complete workflow reaches the final combined taxonomy output.

A validated reference run produced the expected **60.0% residual fraction** from the 40% host / 60% non-host mixture, no residual human node in the Kraken2 report, and recovery of all expected non-human sources. Exact classifier counts are deliberately not treated as universal accuracy targets because short-read taxonomic resolution depends on sequence uniqueness and database taxonomy.

See [`docs/testing.md`](docs/testing.md) for the fixture definition, expected outputs, and validation semantics.

## Requirements

For a real run:

- Nextflow `>=24.04.0`;
- SLURM for the `slurm` profile;
- Apptainer or Singularity;
- paired-end FASTQ files;
- a STAR host index;
- a compatible Kraken2 database;
- a Kaiju database containing `nodes.dmp`, `names.dmp`, and an `.fmi` index;
- the local `.sif` images listed in [`assets/containers.tsv`](assets/containers.tsv).

## 1. Provision containers

Run this once from an environment with registry access:

```bash
CONTAINER_DIR=/shared/metagenomics/containers

bash scripts/pull_containers.sh \
  --output-dir "$CONTAINER_DIR"
```

The helper can load Apptainer automatically on module-based systems when it is not already on `PATH`. Container tags are pinned in [`assets/containers.tsv`](assets/containers.tsv).

## 2. Provision databases

The database helper supports the broad database families used by the workflow:

```bash
DB_ROOT=/shared/metagenomics/databases

bash scripts/download_databases.sh \
  --root "$DB_ROOT" \
  --kraken pluspf \
  --kaiju nr_euk
```

The provisioning script uses resumable HTTPS downloads and inherits `HTTPS_PROXY` / `https_proxy` when configured. Analysis itself does not download databases.

Expected layout:

```text
/shared/metagenomics/databases/
├── kraken2/
│   ├── pluspf/
│   └── pluspfp/
└── kaiju/
    └── nr_euk/
```

Any compatible pre-built database can be used by passing its path directly.

## 3. Run the committed biological smoke test

Once the containers, host index, and classifier databases are staged:

```bash
TEST_DIR="$PWD/tests/fixtures/mock-community"
HOST_INDEX=/shared/references/GRCh38_STAR
KRAKEN2_DB=/shared/metagenomics/databases/kraken2/pluspf
KAIJU_DB=/shared/metagenomics/databases/kaiju/nr_euk
CONTAINER_DIR=/shared/metagenomics/containers
OUTDIR=/shared/results/metagenomics-smoke-test

bash scripts/run_biological_test.sh \
  --test-dir "$TEST_DIR" \
  --host-index "$HOST_INDEX" \
  --kraken2-db "$KRAKEN2_DB" \
  --kaiju-db "$KAIJU_DB" \
  --container-dir "$CONTAINER_DIR" \
  --outdir "$OUTDIR" \
  --profile slurm
```

A successful run ends with:

```text
BIOLOGICAL TEST: PASS
```

To regenerate the fixture from NCBI instead of using the committed FASTQs:

```bash
bash scripts/setup_test_data.sh \
  --output-dir /shared/metagenomics/generated-test-data
```

## 4. Run your own data

Use a CSV samplesheet:

```csv
sample,fastq_1,fastq_2
sample01,/data/sample01_R1.fastq.gz,/data/sample01_R2.fastq.gz
sample02,/data/sample02_R1.fastq.gz,/data/sample02_R2.fastq.gz
```

Relative FASTQ paths are resolved relative to the samplesheet directory. Sample identifiers must be unique and may contain letters, numbers, `.`, `_`, and `-`.

Validate the samplesheet before launching:

```bash
python3 bin/validate_samplesheet.py --input samplesheet.csv
```

## 5. Preflight assets

```bash
bash scripts/verify_assets.sh \
  --container-dir /shared/metagenomics/containers \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk
```

Add `--check-tools` to run lightweight version checks inside the staged containers.

## 6. Run on SLURM

The resumable runner is the main interface:

```bash
bash scripts/run_pipeline.sh \
  --profile slurm \
  --engine auto \
  --input /absolute/path/samplesheet.csv \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk \
  --container-dir /shared/metagenomics/containers \
  --outdir /shared/results/run01
```

To keep the Nextflow controller off the login node:

```bash
sbatch scripts/submit_pipeline.sbatch \
  --input /absolute/path/samplesheet.csv \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk \
  --container-dir /shared/metagenomics/containers \
  --outdir /shared/results/run01
```

No account, partition, username, or site path is hard-coded. Site-specific scheduler options belong in a separate config, for example:

```bash
bash scripts/run_pipeline.sh ... --config /path/to/site.config
```

See [`assets/cluster.config.example`](assets/cluster.config.example).

## Optional host-depletion thresholds

The workflow always writes STAR and Kraken2 host-QC tables. Threshold enforcement is disabled by default because appropriate limits depend on sample type, host reference, and database composition.

```bash
bash scripts/run_pipeline.sh ... \
  --max-star-unmapped-pct <study-specific-percent> \
  --max-kraken-human-pct <study-specific-percent>
```

The Kraken2 threshold assumes the selected database contains host taxid `9606` when human is the host.

## Outputs

```text
results/
├── qc/
│   ├── fastqc/<sample>/
│   └── fastp/<sample>/
├── host_depletion/<sample>/
│   ├── *.Log.final.out
│   ├── *.nonhost_R1.fastq.gz
│   ├── *.nonhost_R2.fastq.gz
│   ├── *.pairing_stats.tsv
│   └── *.star_host_depletion_qc.tsv
├── kraken2/<sample>/
│   ├── *.kraken2.report.tsv
│   ├── *.kraken2.out.tsv
│   └── *.kraken_human_qc.tsv
├── kaiju/<sample>/
│   ├── *.kaiju.out.tsv
│   └── *.kaiju.species.tsv
├── taxonomy/
│   ├── per_sample/*.taxonomy_comparison.tsv
│   └── all_samples.taxonomy_comparison.tsv
└── pipeline_info/
    ├── launch.txt
    ├── execution_report.html
    ├── execution_timeline.html
    ├── execution_trace.txt
    └── pipeline_dag.html
```

## Testing

Two complementary layers are maintained:

1. **CI/stub tests** — fast, deterministic checks of the Nextflow graph, process contracts, Python utilities, shell syntax, and exact stub outputs.
2. **Biological smoke test** — the committed 100-pair fixture is run through real containers and databases and checked against biological/QC invariants.

```bash
nextflow run main.nf -profile test -stub-run
```

GitHub Actions compares the generated stub outputs byte-for-byte with `tests/expected/stub/`. The biological validator reads classifier-specific expectations from `tests/expected/biological_expectations.tsv` and QC ranges from `tests/expected/biological_qc_expectations.tsv`.

See [`docs/testing.md`](docs/testing.md).

## Restricted-network HPC execution

The analysis DAG contains no network downloads. Container, database, and optional fixture regeneration are explicit provisioning operations performed beforehand. The runner also disables Nextflow's nonessential latest-version probe by default so a local Nextflow installation does not wait on outbound HTTPS from restricted compute nodes.

See [`docs/offline-hpc.md`](docs/offline-hpc.md).

## Resource model

The default SLURM resources are conservative settings for broad metagenomics databases and can be overridden with a site-specific Nextflow config.

See [`docs/resources.md`](docs/resources.md).

## Scope

This workflow performs **host depletion and broad taxonomic screening**. A classifier hit is not, by itself, proof of infection, colonisation, or causality. Taxonomic resolution may stop above species when short reads are shared across closely related organisms. Candidate confirmation, biological interpretation, and study-specific downstream analysis intentionally remain outside this generic pipeline.
