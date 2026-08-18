process MERGE_TAXONOMY {
    tag "${meta.id}"
    label 'tiny'

    publishDir "${params.outdir}/taxonomy", mode: 'copy'

    input:
    tuple val(meta), path(kraken_report), path(kaiju_summary)

    output:
    tuple val(meta), path("${meta.id}.taxonomy_comparison.tsv"), emit: table

    script:
    """
    python3 ${projectDir}/bin/merge_taxonomy.py \
      --sample '${meta.id}' \
      --kraken ${kraken_report} \
      --kaiju ${kaiju_summary} \
      --output ${meta.id}.taxonomy_comparison.tsv
    """
}
