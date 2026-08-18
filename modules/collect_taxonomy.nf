process COLLECT_TAXONOMY {
    label 'tiny'

    publishDir { "${params.outdir}/taxonomy" }, mode: 'copy', overwrite: true

    input:
    path tables

    output:
    path 'all_samples.taxonomy_comparison.tsv', emit: table

    script:
    """
    set -euo pipefail
    awk 'FNR==1 && NR!=1 {next} {print}' ${tables.join(' ')} > all_samples.taxonomy_comparison.tsv
    """

    stub:
    """
    printf 'sample\ttaxid\tname\tkraken_percent\tkraken_clade_reads\tkraken_taxon_reads\tkaiju_percent\tkaiju_reads\n' > all_samples.taxonomy_comparison.tsv
    """
}
