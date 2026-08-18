process MERGE_TAXONOMY {
    tag "${meta.id}"
    label 'tiny'

    publishDir { "${params.outdir}/taxonomy/per_sample" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(kraken_report), path(kaiju_summary)
    path merge_script

    output:
    tuple val(meta), path("${meta.id}.taxonomy_comparison.tsv"), emit: table

    script:
    """
    set -euo pipefail
    python3 '${merge_script}' \
      --sample '${meta.id}' \
      --kraken '${kraken_report}' \
      --kaiju '${kaiju_summary}' \
      --output '${meta.id}.taxonomy_comparison.tsv'
    """

    stub:
    """
    printf 'sample\ttaxid\tname\tkraken_percent\tkraken_clade_reads\tkraken_taxon_reads\tkaiju_percent\tkaiju_reads\n${meta.id}\t562\tEscherichia coli\t90.0\t90\t90\t90.0\t90\n' > '${meta.id}.taxonomy_comparison.tsv'
    """
}
