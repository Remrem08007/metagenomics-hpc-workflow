process FASTP {
    tag "${meta.id}"
    label 'medium'

    publishDir "${params.outdir}/qc/fastp", mode: 'copy', pattern: '*.{html,json}'

    input:
    tuple val(meta), path(read1), path(read2)

    output:
    tuple val(meta), path("${meta.id}.trimmed_R1.fastq.gz"), path("${meta.id}.trimmed_R2.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.fastp.html"), path("${meta.id}.fastp.json"), emit: reports

    script:
    """
    fastp \
      --in1 ${read1} \
      --in2 ${read2} \
      --out1 ${meta.id}.trimmed_R1.fastq.gz \
      --out2 ${meta.id}.trimmed_R2.fastq.gz \
      --html ${meta.id}.fastp.html \
      --json ${meta.id}.fastp.json \
      --thread ${task.cpus}
    """
}
