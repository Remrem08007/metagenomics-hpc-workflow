process STAR_HOST_ALIGN {
    tag "${meta.id}"
    label 'large'

    publishDir "${params.outdir}/host_depletion", mode: 'copy', pattern: '*.Log.final.out'

    input:
    tuple val(meta), path(read1), path(read2)
    val host_index

    output:
    tuple val(meta), path("${meta.id}.Aligned.out.bam"), emit: bam
    tuple val(meta), path("${meta.id}.Log.final.out"), emit: log

    script:
    """
    STAR \
      --genomeDir ${host_index} \
      --readFilesIn ${read1} ${read2} \
      --readFilesCommand zcat \
      --runThreadN ${task.cpus} \
      --outSAMtype BAM Unsorted \
      --outSAMunmapped Within KeepPairs \
      --outFileNamePrefix ${meta.id}.
    """
}
