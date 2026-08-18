process VALIDATE_KRAKEN_HUMAN {
    tag "${meta.id}"
    label 'tiny'

    publishDir { "${params.outdir}/kraken2/${meta.id}" }, mode: 'copy', pattern: '*.kraken_human_qc.tsv', overwrite: true

    input:
    tuple val(meta), path(kraken_report)
    path validator

    output:
    tuple val(meta), path(kraken_report), emit: report
    tuple val(meta), path("${meta.id}.kraken_human_qc.tsv"), emit: qc

    script:
    def threshold = params.max_kraken_human_pct as double
    def thresholdArg = threshold >= 0 ? "--max-human-pct ${threshold}" : ''
    """
    set -euo pipefail
    python3 '${validator}' kraken \
      --report '${kraken_report}' \
      --sample '${meta.id}' \
      --human-taxid ${params.human_taxid} \
      --output '${meta.id}.kraken_human_qc.tsv' \
      ${thresholdArg}
    """

    stub:
    """
    printf 'sample\thuman_taxid\thuman_pct\tthreshold_pct\tstatus\n${meta.id}\t${params.human_taxid}\t1.0\tNA\tPASS\n' > '${meta.id}.kraken_human_qc.tsv'
    """
}
