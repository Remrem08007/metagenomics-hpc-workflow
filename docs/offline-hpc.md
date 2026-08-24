# Offline / restricted-network HPC execution

The analysis workflow is designed so that submitted compute tasks do **not** require internet access.

## Provisioning versus analysis

Provisioning is explicit and separate from analysis:

1. pull the required Apptainer/Singularity images;
2. download or stage Kraken2 and Kaiju databases;
3. stage or build the host STAR index;
4. run `scripts/verify_assets.sh`;
5. launch Nextflow from the local repository checkout.

Provisioning helpers inherit `HTTPS_PROXY` / `https_proxy` when configured. The analysis DAG itself contains no `curl`, `wget`, registry pulls, NCBI API calls, or remote Nextflow module dependencies.

The biological FASTQ fixture is committed under `tests/fixtures/mock-community/`, so the smoke test can use its input reads without contacting NCBI. NCBI access is needed only if the fixture is intentionally regenerated from public reference provenance with `scripts/setup_test_data.sh`.

## Nextflow launcher behavior

The runner sets:

```bash
NXF_DISABLE_CHECK_LATEST=true
```

by default unless the caller has explicitly set a different value. This suppresses Nextflow's nonessential latest-version HTTP probe, which can otherwise wait for a network timeout on restricted compute nodes even when the required local Nextflow runtime is already available.

This is narrower than forcing `NXF_OFFLINE=true`: it disables the version check without globally changing other Nextflow networking behavior.

## Containers

Pull images once from an environment with registry access:

```bash
CONTAINER_DIR=/shared/metagenomics/containers

bash scripts/pull_containers.sh \
  --output-dir "$CONTAINER_DIR"
```

Then pass the local directory to every analysis run:

```bash
--container-dir "$CONTAINER_DIR"
```

The workflow refers directly to local `.sif` files, so analysis jobs do not need to contact a container registry.

## Large references and databases

The STAR, Kraken2, and Kaiju directories remain on shared storage and are passed as paths. Container profiles bind those locations rather than copying hundreds of gigabytes into individual Nextflow work directories.

Example layout:

```text
/shared/metagenomics/
├── containers/
├── databases/
│   ├── kraken2/pluspf/
│   └── kaiju/nr_euk/
└── results/

/shared/references/
└── GRCh38_STAR/
```

These paths are examples only; the public workflow does not hard-code a site filesystem layout.

## Launch pattern

The normal runner can be launched directly:

```bash
bash scripts/run_pipeline.sh \
  --profile slurm \
  --input /path/to/samplesheet.csv \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk \
  --container-dir /shared/metagenomics/containers \
  --outdir /shared/metagenomics/results/run01
```

Or use the lightweight orchestration wrapper so the Nextflow controller itself runs under SLURM:

```bash
sbatch scripts/submit_pipeline.sbatch \
  --input /path/to/samplesheet.csv \
  --host-index /shared/references/GRCh38_STAR \
  --kraken2-db /shared/metagenomics/databases/kraken2/pluspf \
  --kaiju-db /shared/metagenomics/databases/kaiju/nr_euk \
  --container-dir /shared/metagenomics/containers \
  --outdir /shared/metagenomics/results/run01
```

The orchestration job runs Nextflow; Nextflow submits the computational processes as separate SLURM jobs.

## Site-specific settings

No account, partition, username, or private path is stored in the public configuration. Scheduler-specific settings should be supplied in an additional Nextflow config:

```bash
bash scripts/run_pipeline.sh ... --config /path/to/site.config
```

See `assets/cluster.config.example` for a minimal template.
