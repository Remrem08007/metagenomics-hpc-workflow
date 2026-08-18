process KRAKEN2_CLASSIFY {
    tag "${meta.id}"
    label 'kraken2'

    publishDir { "${params.outdir}/kraken2/${meta.id}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2)
    val kraken2_db

    output:
    tuple val(meta), path("${meta.id}.kraken2.report.tsv"), emit: report
    tuple val(meta), path("${meta.id}.kraken2.out.tsv"), emit: classifications

    script:
    def compressed = (read1.name.endsWith('.gz') && read2.name.endsWith('.gz')) ? '--gzip-compressed' : ''
    """
    set -euo pipefail
    test -f '${kraken2_db}/hash.k2d' || { echo 'Missing Kraken2 hash.k2d: ${kraken2_db}' >&2; exit 2; }
    test -f '${kraken2_db}/opts.k2d' || { echo 'Missing Kraken2 opts.k2d: ${kraken2_db}' >&2; exit 2; }
    test -f '${kraken2_db}/taxo.k2d' || { echo 'Missing Kraken2 taxo.k2d: ${kraken2_db}' >&2; exit 2; }

    kraken2 \
      --db '${kraken2_db}' \
      --threads ${task.cpus} \
      --paired \
      ${compressed} \
      --report '${meta.id}.kraken2.report.tsv' \
      --output '${meta.id}.kraken2.out.tsv' \
      '${read1}' '${read2}'
    """

    stub:
    """
    cat > '${meta.id}.kraken2.report.tsv' <<'TSV'
 90.00\t90\t90\tS\t562\tEscherichia coli
  1.00\t1\t1\tS\t9606\tHomo sapiens
TSV
    printf 'C\tstub\t562\t4\t0:1\n' > '${meta.id}.kraken2.out.tsv'
    """
}
