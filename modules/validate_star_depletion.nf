process VALIDATE_STAR_DEPLETION {
    tag "${meta.id}"
    label 'tiny'

    publishDir { "${params.outdir}/host_depletion/${meta.id}" }, mode: 'copy', pattern: '*.star_host_depletion_qc.tsv', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2), path(star_log)
    path validator

    output:
    tuple val(meta), path(read1), path(read2), emit: reads
    tuple val(meta), path("${meta.id}.star_host_depletion_qc.tsv"), emit: qc

    script:
    def threshold = params.max_star_unmapped_pct as double
    def thresholdArg = threshold >= 0 ? "--max-unmapped-pct ${threshold}" : ''
    """
    set -euo pipefail
    python3 '${validator}' star \
      --log '${star_log}' \
      --sample '${meta.id}' \
      --output '${meta.id}.star_host_depletion_qc.tsv' \
      ${thresholdArg}
    """

    stub:
    """
    printf 'sample\tinput_reads\tresidual_pct\tthreshold_pct\tstatus\n${meta.id}\t1\t100.0\tNA\tPASS\n' > '${meta.id}.star_host_depletion_qc.tsv'
    """
}
