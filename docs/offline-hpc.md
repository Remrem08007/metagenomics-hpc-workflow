# Offline / restricted-network HPC execution

The analysis DAG is designed so that submitted SLURM tasks do not require internet access.

## Required before a run

Stage the following on storage visible from the compute nodes:

1. the pipeline checkout;
2. pre-pulled Singularity/Apptainer `.sif` images;
3. a STAR host genome index;
4. a Kraken2 database;
5. a Kaiju database containing an `.fmi` index plus `nodes.dmp` and `names.dmp`;
6. the input FASTQ files.

The workflow points each process at an absolute local `.sif` path. This avoids Nextflow trying to pull or convert a registry image when a task starts.

Large STAR, Kraken2, and Kaiju directories are passed to processes as path strings rather than Nextflow `path` inputs, so Nextflow does not stage/copy those databases into every task directory. Those shared-filesystem locations therefore need to be visible inside the container runtime. If your cluster does not bind them automatically, add Singularity/Apptainer bind options in the site-specific config.

## Proxy-aware provisioning

Provisioning helpers may access HTTPS resources and inherit proxy variables such as:

```bash
export HTTPS_PROXY='http://proxy.example:port'
export https_proxy="$HTTPS_PROXY"
```

No proxy address is stored in the repository.

## Site-specific SLURM settings

`conf/slurm.config` intentionally does not hard-code account, partition, queue, or cluster-specific paths. Add them in a private/site config:

```groovy
process {
    queue = 'your_partition'
    clusterOptions = '--account=your_account'
}
```

Run with:

```bash
nextflow run main.nf \
  -profile slurm \
  -c conf/my_cluster.config \
  --input /absolute/path/samplesheet.csv \
  --container_dir /absolute/path/containers \
  --host_index /absolute/path/star_index \
  --kraken2_db /absolute/path/kraken2_db \
  --kaiju_db /absolute/path/kaiju_db \
  --outdir /absolute/path/results
```
