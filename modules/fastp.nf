process FASTP {
    tag "${meta.id}"
    label 'medium'

    publishDir { "${params.outdir}/qc/fastp/${meta.id}" }, mode: 'copy', pattern: '*.{html,json,log}', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2)

    output:
    tuple val(meta), path("${meta.id}.trimmed_R1.fastq.gz"), path("${meta.id}.trimmed_R2.fastq.gz"), emit: reads
    tuple val(meta), path("${meta.id}.fastp.html"), path("${meta.id}.fastp.json"), path("${meta.id}.fastp.log"), emit: reports

    script:
    """
    set -euo pipefail
    fastp \
      --in1 '${read1}' \
      --in2 '${read2}' \
      --out1 '${meta.id}.trimmed_R1.fastq.gz' \
      --out2 '${meta.id}.trimmed_R2.fastq.gz' \
      --thread ${task.cpus} \
      --detect_adapter_for_pe \
      --trim_poly_g \
      --trim_poly_x \
      --cut_front \
      --cut_tail \
      --cut_window_size 4 \
      --cut_mean_quality ${params.fastp_cut_mean_quality} \
      --qualified_quality_phred ${params.fastp_qualified_quality_phred} \
      --unqualified_percent_limit ${params.fastp_unqualified_percent_limit} \
      --length_required ${params.fastp_min_length} \
      --html '${meta.id}.fastp.html' \
      --json '${meta.id}.fastp.json' \
      2> '${meta.id}.fastp.log'
    """

    stub:
    """
    printf '@${meta.id}/1\nACGT\n+\nIIII\n' | gzip -c > '${meta.id}.trimmed_R1.fastq.gz'
    printf '@${meta.id}/2\nTGCA\n+\nIIII\n' | gzip -c > '${meta.id}.trimmed_R2.fastq.gz'
    printf '<html><body>stub</body></html>\n' > '${meta.id}.fastp.html'
    printf '{}\n' > '${meta.id}.fastp.json'
    printf 'stub fastp output\n' > '${meta.id}.fastp.log'
    """
}
