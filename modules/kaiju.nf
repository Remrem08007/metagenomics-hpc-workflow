process KAIJU_CLASSIFY {
    tag "${meta.id}"
    label 'kaiju'

    publishDir { "${params.outdir}/kaiju/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2)
    val kaiju_db

    output:
    tuple val(meta), path("${meta.id}.kaiju.out.tsv"), emit: classifications
    tuple val(meta), path("${meta.id}.kaiju.species.tsv"), emit: summary

    script:
    def requestedFmi = params.kaiju_fmi ? params.kaiju_fmi.toString() : ''
    def expandViruses = params.kaiju_expand_viruses ? '-e' : ''
    """
    set -euo pipefail

    test -f '${kaiju_db}/nodes.dmp' || { echo 'Missing Kaiju nodes.dmp: ${kaiju_db}' >&2; exit 2; }
    test -f '${kaiju_db}/names.dmp' || { echo 'Missing Kaiju names.dmp: ${kaiju_db}' >&2; exit 2; }

    requested_fmi='${requestedFmi}'
    if [[ -n "\$requested_fmi" ]]; then
        FMI='${kaiju_db}'/"\$requested_fmi"
        test -f "\$FMI" || { echo "Missing Kaiju index: \$FMI" >&2; exit 2; }
    else
        mapfile -t fmis < <(find '${kaiju_db}' -maxdepth 1 -type f -name '*.fmi' | sort)
        [[ \${#fmis[@]} -eq 1 ]] || {
            echo "Expected exactly one .fmi in ${kaiju_db}; found \${#fmis[@]}. Use --kaiju_fmi to choose one." >&2
            exit 2
        }
        FMI="\${fmis[0]}"
    fi

    kaiju \
      -t '${kaiju_db}/nodes.dmp' \
      -f "\$FMI" \
      -i '${read1}' \
      -j '${read2}' \
      -z ${task.cpus} \
      -o '${meta.id}.kaiju.out.tsv'

    kaiju2table \
      -t '${kaiju_db}/nodes.dmp' \
      -n '${kaiju_db}/names.dmp' \
      -r species \
      ${expandViruses} \
      -o '${meta.id}.kaiju.species.tsv' \
      '${meta.id}.kaiju.out.tsv'
    """

    stub:
    """
    printf 'C\tstub\t562\n' > '${meta.id}.kaiju.out.tsv'
    printf 'file\tpercent\treads\ttaxon_id\ttaxon_name\n${meta.id}.kaiju.out.tsv\t90.000000\t90\t562\tEscherichia coli\n' > '${meta.id}.kaiju.species.tsv'
    """
}
