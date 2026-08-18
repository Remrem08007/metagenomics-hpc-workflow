process FASTQC {
    tag "${meta.id}"
    label 'small'

    publishDir { "${params.outdir}/qc/fastqc/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*_fastqc.html'), emit: html
    tuple val(meta), path('*_fastqc.zip'), emit: zip

    script:
    """
    set -euo pipefail
    fastqc --threads ${task.cpus} ${reads.join(' ')}
    """

    stub:
    """
    for read in ${reads.join(' ')}; do
        base=\$(basename "\$read")
        base=\${base%.gz}
        base=\${base%.fastq}
        base=\${base%.fq}
        touch "\${base}_fastqc.html" "\${base}_fastqc.zip"
    done
    """
}
