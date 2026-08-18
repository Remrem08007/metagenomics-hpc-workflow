process EXTRACT_NONHOST_PAIRS {
    tag "${meta.id}"
    label 'medium'

    publishDir { "${params.outdir}/host_depletion/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(bam), path(star_log)

    output:
    tuple val(meta), path("${meta.id}.nonhost_R1.fastq.gz"), path("${meta.id}.nonhost_R2.fastq.gz"), path(star_log), emit: reads_with_log
    tuple val(meta), path("${meta.id}.pairing_stats.tsv"), emit: stats

    script:
    """
    set -euo pipefail

    # 0x1 + 0x4 + 0x8 = paired, read unmapped, mate unmapped.
    # Exclude secondary (0x100) and supplementary (0x800) alignments.
    samtools view \
      -@ ${task.cpus} \
      -u \
      -f 13 \
      -F 2304 \
      '${bam}' \
      | samtools sort -n -@ ${task.cpus} -O BAM -o '${meta.id}.both_unmapped.name.bam' -

    records=\$(samtools view -c '${meta.id}.both_unmapped.name.bam')
    pairs=\$(( records / 2 ))
    printf 'sample\tboth_unmapped_records\tboth_unmapped_pairs\n%s\t%s\t%s\n' \
      '${meta.id}' "\$records" "\$pairs" \
      > '${meta.id}.pairing_stats.tsv'

    samtools fastq \
      -@ ${task.cpus} \
      -1 >(gzip -c > '${meta.id}.nonhost_R1.fastq.gz') \
      -2 >(gzip -c > '${meta.id}.nonhost_R2.fastq.gz') \
      -0 /dev/null \
      -s /dev/null \
      -n \
      '${meta.id}.both_unmapped.name.bam'
    """

    stub:
    """
    printf '@${meta.id}/1\nACGT\n+\nIIII\n' | gzip -c > '${meta.id}.nonhost_R1.fastq.gz'
    printf '@${meta.id}/2\nTGCA\n+\nIIII\n' | gzip -c > '${meta.id}.nonhost_R2.fastq.gz'
    printf 'sample\tboth_unmapped_records\tboth_unmapped_pairs\n${meta.id}\t2\t1\n' > '${meta.id}.pairing_stats.tsv'
    """
}
