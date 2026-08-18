process KRAKEN2_CLASSIFY {
    tag "${meta.id}"
    label 'large'

    publishDir "${params.outdir}/kraken2", mode: 'copy'

    input:
    tuple val(meta), path(read1), path(read2)
    val kraken2_db

    output:
    tuple val(meta), path("${meta.id}.kraken2.report.tsv"), emit: report
    tuple val(meta), path("${meta.id}.kraken2.out.tsv"), emit: classifications

    script:
    """
    kraken2 \
      --db ${kraken2_db} \
      --threads ${task.cpus} \
      --paired \
      --gzip-compressed \
      --use-names \
      --report ${meta.id}.kraken2.report.tsv \
      --output ${meta.id}.kraken2.out.tsv \
      ${read1} ${read2}
    """
}
