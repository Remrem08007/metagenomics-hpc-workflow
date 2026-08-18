# Offline / restricted-network HPC execution

The analysis workflow is designed so that submitted compute tasks do **not** need internet access.

## Provisioning versus analysis

Provisioning is explicit and separate:

1. pull the required Singularity/Apptainer images;
2. download or stage Kraken2 and Kaiju databases;
3. stage/build the host STAR index;
4. run `scripts/verify_assets.sh`;
5. launch Nextflow from the local repository checkout.

The provisioning scripts inherit `HTTPS_PROXY` and `https_proxy`, so they can be used from an environment where outbound HTTPS is available through a proxy.

The Nextflow DAG itself contains no `curl`, `wget`, registry pulls, NCBI API calls, or remote pipeline/module dependencies.

## Containers

Pull once:

```bash
scripts/pull_containers.sh \
  --output-dir "$SCRATCH/metagenomics_containers"
```

Then pass that directory to every run:

```bash
--container-dir "$SCRATCH/metagenomics_containers"
```

The workflow refers directly to local `.sif` files. Nextflow is therefore not expected to contact a container registry from a compute node.

## Large reference directories

The STAR, Kraken2 and Kaiju database directories are kept on shared storage and passed as absolute paths. The Singularity configuration explicitly binds those directories into each container rather than staging hundreds of gigabytes into individual Nextflow work directories.

## Launch pattern

Load Nextflow and Singularity/Apptainer in the submission environment, then use the small orchestration job. The runner detects the available container command and selects the matching Nextflow profile:

```bash
sbatch scripts/submit_pipeline.sbatch \
  --input /path/samplesheet.csv \
  --host-index /shared/ref/GRCh38_STAR \
  --kraken2-db /shared/db/kraken2/pluspf \
  --kaiju-db /shared/db/kaiju/nr_euk \
  --container-dir /shared/containers \
  --outdir /shared/results/run01
```

The orchestration job runs Nextflow; Nextflow submits the computational processes as separate SLURM jobs.
