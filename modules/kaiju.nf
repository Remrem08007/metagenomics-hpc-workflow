process KAIJU_CLASSIFY {
    tag "${meta.id}"
    label 'large'

    publishDir "${params.outdir}/kaiju", mode: 'copy'

    input:
    tuple val(meta), path(read1), path(read2)
    val kaiju_db

    output:
    tuple val(meta), path("${meta.id}.kaiju.out.tsv"), emit: classifications
    tuple val(meta), path("${meta.id}.kaiju.species.tsv"), emit: summary

    script:
    """
    FMI=${kaiju_db}/${params.kaiju_fmi}
    test -f "\$FMI" || { echo "Missing Kaiju index: \$FMI" >&2; exit 2; }
    test -f ${kaiju_db}/nodes.dmp || { echo "Missing nodes.dmp in ${kaiju_db}" >&2; exit 2; }
    test -f ${kaiju_db}/names.dmp || { echo "Missing names.dmp in ${kaiju_db}" >&2; exit 2; }

    kaiju \
      -t ${kaiju_db}/nodes.dmp \
      -f "\$FMI" \
      -i ${read1} \
      -j ${read2} \
      -z ${task.cpus} \
      -o ${meta.id}.kaiju.out.tsv

    kaiju2table \
      -t ${kaiju_db}/nodes.dmp \
      -n ${kaiju_db}/names.dmp \
      -r species \
      -o ${meta.id}.kaiju.species.tsv \
      ${meta.id}.kaiju.out.tsv
    """
}
