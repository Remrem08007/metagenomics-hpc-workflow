process EXTRACT_NONHOST_PAIRS {
    tag "${meta.id}"
    label 'medium'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.nonhost_R1.fastq.gz"), path("${meta.id}.nonhost_R2.fastq.gz"), emit: reads

    script:
    """
    # 0x4 + 0x8 = both read and mate unmapped.
    # Exclude secondary (0x100) and supplementary (0x800) records.
    samtools view \
      -@ ${task.cpus} \
      -b \
      -f 12 \
      -F 2304 \
      ${bam} \
      -o ${meta.id}.both_unmapped.bam

    samtools fastq \
      -@ ${task.cpus} \
      -1 >(gzip -c > ${meta.id}.nonhost_R1.fastq.gz) \
      -2 >(gzip -c > ${meta.id}.nonhost_R2.fastq.gz) \
      -0 /dev/null \
      -s /dev/null \
      -n \
      ${meta.id}.both_unmapped.bam
    """
}
