# Metagenomics HPC Workflow

A reusable **Nextflow DSL2** workflow for paired-end sequencing data that performs quality control, trimming, sensitive host depletion, and complementary nucleotide- and protein-level taxonomic classification.

The workflow is designed for HPC environments where **SLURM compute nodes do not have direct internet access**. Database/container provisioning is separated from analysis, and Nextflow jobs consume only pre-staged references and pre-pulled `.sif` images from shared storage.

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

Kraken2 and Kaiju counts are reported **side-by-side**, not added together, because the classifiers use different search strategies.

## Key design choices

- paired-end FASTQ input;
- FastQC + configurable fastp trimming;
- splice-aware STAR host subtraction;
- strict non-host extraction requires both mates to be unmapped;
- Kraken2 paired nucleotide classification;
- Kaiju paired protein-level classification with species summaries;
- optional STAR and residual-human QC thresholds;
- local `.sif` images only during analysis;
- large databases remain on shared storage instead of being staged into task work directories;
- `local`/`slurm` execution profiles plus explicit `singularity`/`apptainer` container profiles;
- resumable runner and small SLURM orchestration wrapper;
- deterministic test data, ground truth, expected outputs and CI fixtures;
- no lab/project-specific paths, sample conventions, or biological interpretation logic.

## Requirements

For production runs:

- Nextflow `>=24.04.0`
- SLURM (for `-profile slurm`)
- Apptainer or Singularity
- paired-end FASTQ files
- a STAR host index
- a Kraken2 database
- a Kaiju database (`nodes.dmp`, `names.dmp`, and one `.fmi` index)
- the pre-pulled containers in `assets/containers.tsv`

## 1. Pull containers

Run where registry access is available. `HTTPS_PROXY` / `https_proxy` are inherited when configured:

```bash
bash scripts/pull_containers.sh \
  --output-dir "$SCRATCH/metagenomics_containers"
```

On module-based clusters the helper tries to load Apptainer automatically when it is not already on `PATH`.

Container tags are pinned in [`assets/containers.tsv`](assets/containers.tsv).

## 2. Prepare databases

A helper is provided for the broad database families used by the workflow design:

```bash
bash scripts/download_databases.sh \
  --root "$SCRATCH/metagenomics_databases" \
  --kraken pluspf \
  --kaiju nr_euk
```

The helper currently pins Kraken2 PlusPF/PlusPFP to the `20260626` release and Kaiju `nr_euk` to `2023-05-10`. It uses resumable HTTPS downloads and inherits `HTTPS_PROXY` / `https_proxy`.

Expected layout:

```text
$SCRATCH/metagenomics_databases/
├── kraken2/
│   ├── pluspf/
│   └── pluspfp/
└── kaiju/
    └── nr_euk/
```

You may use any compatible database instead by passing its absolute path.

## 3. Recommended first run: reproducible mock community

You do **not** need to find your own FASTQs to test the repository.

Generate the supplied biological test dataset:

```bash
bash scripts/setup_test_data.sh \
  --output-dir "$SCRATCH/metagenomics_test"
```

The script downloads small, versioned RefSeq segments over HTTPS and generates a deterministic 100-pair mixture:

- 40 human GRCh38 pairs;
- 30 *Escherichia coli* pairs;
- 20 *Saccharomyces cerevisiae* pairs;
- 10 influenza A pairs.

It creates the FASTQs, a ready-to-use samplesheet, a per-read ground-truth table, the mixture definition, and expected taxonomic results:

```text
$SCRATCH/metagenomics_test/
├── README.txt
├── references/
└── data/
    ├── mock-community_R1.fastq.gz
    ├── mock-community_R2.fastq.gz
    ├── samplesheet.csv
    ├── ground_truth.tsv
    ├── mixture.tsv
    └── expected_taxa.tsv
```

Once containers, databases and your GRCh38 STAR index are available, run and validate the complete biological smoke test with one command:

```bash
bash scripts/run_biological_test.sh \
  --test-dir "$SCRATCH/metagenomics_test" \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk" \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --outdir "$SCRATCH/metagenomics_test_results"
```

A successful validated run ends with:

```text
BIOLOGICAL TEST: PASS
```

See [`docs/testing.md`](docs/testing.md) for the exact ground truth and validation rules.

## 4. Samplesheet for your own data

For normal analyses, provide:

```csv
sample,fastq_1,fastq_2
sample01,/data/sample01_R1.fastq.gz,/data/sample01_R2.fastq.gz
sample02,/data/sample02_R1.fastq.gz,/data/sample02_R2.fastq.gz
```

The `/data/...` paths above are examples only. Replace them with real paths on your system. Relative FASTQ paths are resolved relative to the samplesheet directory. Sample identifiers must be unique and may contain letters, numbers, `.`, `_`, and `-`.

Validate before running:

```bash
python3 bin/validate_samplesheet.py --input samplesheet.csv
```

## 5. Preflight assets

```bash
bash scripts/verify_assets.sh \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk"
```

Add `--check-tools` to execute a lightweight version check inside each `.sif`.

## 6. Run on SLURM

The recommended interface is the resumable wrapper:

```bash
bash scripts/run_pipeline.sh \
  --profile slurm \
  --engine auto \
  --input /absolute/path/samplesheet.csv \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk" \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --outdir "$SCRATCH/metagenomics_results/run01"
```

To keep the Nextflow controller off the login node:

```bash
sbatch scripts/submit_pipeline.sbatch \
  --input /absolute/path/samplesheet.csv \
  --host-index "$SCRATCH/references/GRCh38_STAR" \
  --kraken2-db "$SCRATCH/metagenomics_databases/kraken2/pluspf" \
  --kaiju-db "$SCRATCH/metagenomics_databases/kaiju/nr_euk" \
  --container-dir "$SCRATCH/metagenomics_containers" \
  --outdir "$SCRATCH/metagenomics_results/run01"
```

No account or partition is hard-coded. Add site settings in an extra config, for example:

```bash
bash scripts/run_pipeline.sh ... --config conf/my_cluster.config
```

See [`assets/cluster.config.example`](assets/cluster.config.example).

## Optional host-depletion thresholds

The workflow always writes STAR and Kraken2 host-QC tables. Threshold enforcement is disabled by default because appropriate limits depend on sample type and database composition.

Enable thresholds when appropriate:

```bash
bash scripts/run_pipeline.sh ... \
  --max-star-unmapped-pct <study-specific-percent> \
  --max-kraken-human-pct <study-specific-percent>
```

The Kraken threshold assumes the chosen Kraken2 database contains human taxid `9606`.

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

## Test layers and expected outputs

The repository deliberately has two test levels.

### Exact CI/stub outputs

```bash
nextflow run main.nf -profile test -stub-run
```

GitHub Actions compares the generated stub outputs byte-for-byte against files under:

```text
tests/expected/stub/
```

This catches changes to pipeline wiring and output contracts.

### Biological expectations

The mock-community test uses real containers and databases. Exact classifier counts are not forced because Kraken2 and Kaiju use different algorithms and database structures. Instead, `bin/validate_test_run.py` checks predefined biological invariants from:

```text
tests/expected/biological_expectations.tsv
```

The current test requires *E. coli* and *S. cerevisiae* to be detected by both classifiers, influenza A to be recovered by Kraken2, the STAR residual fraction to match the known 40% host / 60% non-host mixture within tolerance, and residual human Kraken2 signal to remain low.

See [`docs/testing.md`](docs/testing.md) for details.

## Restricted-network execution

See [`docs/offline-hpc.md`](docs/offline-hpc.md). The analysis DAG performs no network downloads. Container, database, and test-reference downloads are explicit provisioning steps run beforehand.

## Resource model

The SLURM defaults are intentionally sized for broad databases rather than toy examples. See [`docs/resources.md`](docs/resources.md) and override them with a site-specific config if needed.

## Scope

This workflow performs host depletion and broad taxonomic screening. A classifier hit is not, by itself, biological proof of infection, colonisation, or causality. Downstream confirmation and study-specific interpretation belong outside this generic pipeline.
