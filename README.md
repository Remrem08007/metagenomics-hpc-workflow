# Metagenomics HPC Workflow

A reusable **Nextflow DSL2** workflow for paired-end sequencing data that performs quality control, trimming, host depletion, and complementary nucleotide- and protein-level taxonomic classification.

The project is designed for research-computing environments where **SLURM compute nodes may not have direct internet access**. Analysis tasks use pre-staged databases and pre-pulled Singularity/Apptainer images from a shared filesystem.

## Workflow

```text
Paired FASTQ
   │
   ├── FastQC
   │
   ▼
 fastp
   │
   ▼
STAR host alignment
   │
   ▼
retain read pairs where both mates are unmapped
   │
   ├───────────────┐
   ▼               ▼
Kraken2          Kaiju
(nucleotide)     (protein)
   │               │
   └───────┬───────┘
           ▼
 classifier comparison table
```

Kraken2 and Kaiju results are reported side-by-side. Their read counts are **not added together**, because they represent different classification strategies.

## Design constraints

- paired-end FASTQ input;
- strict host depletion retains only read pairs for which both mates are unmapped from the host reference;
- no downloads inside ordinary Nextflow analysis processes;
- local `.sif` containers supplied through `--container_dir`;
- databases and reference indexes supplied as absolute local paths;
- network/proxy use limited to explicit provisioning scripts;
- generic SLURM configuration with no institution-specific accounts or paths.

## Inputs

Samplesheet:

```csv
sample,fastq_1,fastq_2
sample01,/data/sample01_R1.fastq.gz,/data/sample01_R2.fastq.gz
```

Required runtime parameters:

- `--input`
- `--container_dir`
- `--host_index`
- `--kraken2_db`
- `--kaiju_db`

Kaiju defaults to an index named `kaiju_db.fmi`; override with `--kaiju_fmi` when needed.

## Pre-flight validation

Before launching a large run:

```bash
scripts/verify_assets.sh \
  --container-dir /shared/containers \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/databases/kraken2 \
  --kaiju-db /shared/databases/kaiju
```

## Run locally

The local profile still uses pre-pulled Singularity/Apptainer images:

```bash
nextflow run main.nf \
  -profile local \
  --input /absolute/path/samplesheet.csv \
  --container_dir /absolute/path/containers \
  --host_index /absolute/path/star_index \
  --kraken2_db /absolute/path/kraken2_db \
  --kaiju_db /absolute/path/kaiju_db \
  --outdir /absolute/path/results
```

## Run on SLURM

```bash
nextflow run main.nf \
  -profile slurm \
  --input /absolute/path/samplesheet.csv \
  --container_dir /absolute/path/containers \
  --host_index /absolute/path/star_index \
  --kraken2_db /absolute/path/kraken2_db \
  --kaiju_db /absolute/path/kaiju_db \
  --outdir /absolute/path/results
```

Cluster-specific account/partition settings belong in an extra local config rather than in the public repository.

## Provisioning

Container and archive download helpers are intentionally separate from the analysis DAG:

```bash
scripts/pull_containers.sh --manifest assets/containers.tsv --output-dir /shared/containers
scripts/download_archives.sh --manifest assets/downloads.tsv --output-dir /shared/downloads
```

These scripts inherit `HTTPS_PROXY` / `https_proxy` if they are set.

See [`docs/offline-hpc.md`](docs/offline-hpc.md) for the restricted-network execution model.

## Outputs

```text
results/
├── qc/
│   ├── fastqc/
│   └── fastp/
├── host_depletion/
├── kraken2/
├── kaiju/
├── taxonomy/
└── pipeline_info/
```

The taxonomy table contains Kraken2 and Kaiju species-level results side-by-side by NCBI taxid.

## Status

This repository is an initial public implementation. The next development milestones are a small reproducible mock community test dataset, pinned container manifest, automated test profile, and CI/static validation.
