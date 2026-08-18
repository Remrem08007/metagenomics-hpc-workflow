# Resource model

The default SLURM profile is sized for large pre-built metagenomics databases rather than toy databases.

| Process | CPUs | Memory | Time |
| --- | ---: | ---: | ---: |
| FastQC | 2 | 6 GB | 4 h |
| fastp | 4 | 16 GB | 8 h |
| STAR host alignment | 16 | 64 GB | 24 h |
| non-host pair extraction | 4 | 16 GB | 8 h |
| Kraken2 | 24 | 300 GB | 48 h |
| Kaiju | 24 | 240 GB | 48 h |
| Python summaries | 1 | 2 GB | 1 h |

These are conservative defaults for broad databases such as Kraken2 PlusPF/PlusPFP and Kaiju `nr_euk`. Sites with different databases or hardware should override resources in an additional config passed with `-c`.

The public SLURM config deliberately does not hard-code an account or partition.
