process STAR_HOST_ALIGN {
    tag "${meta.id}"
    label 'star'

    publishDir { "${params.outdir}/host_depletion/${meta.id}" }, mode: 'copy', pattern: '*.Log.final.out', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2)
    val host_index

    output:
    tuple val(meta), path("${meta.id}.Aligned.out.bam"), path("${meta.id}.Log.final.out"), emit: alignment

    script:
    def readFilesCommand = (read1.name.endsWith('.gz') && read2.name.endsWith('.gz')) ? '--readFilesCommand zcat' : ''
    """
    set -euo pipefail
    STAR \
      --genomeDir '${host_index}' \
      --readFilesIn '${read1}' '${read2}' \
      ${readFilesCommand} \
      --runThreadN ${task.cpus} \
      --outSAMtype BAM Unsorted \
      --outSAMunmapped Within KeepPairs \
      --outFileNamePrefix '${meta.id}.' \
      --outFilterMultimapNmax ${params.star_multimap_max} \
      --winAnchorMultimapNmax ${params.star_anchor_multimap_max} \
      --outFilterMismatchNoverReadLmax ${params.star_mismatch_ratio_max} \
      --outFilterScoreMinOverLread ${params.star_score_min_over_read} \
      --outFilterMatchNminOverLread ${params.star_match_min_over_read}
    """

    stub:
    """
    touch '${meta.id}.Aligned.out.bam'
    cat > '${meta.id}.Log.final.out' <<'LOG'
                          Number of input reads |       1
                   Uniquely mapped reads number |       0
                        Uniquely mapped reads % |       0.00%
        Number of reads mapped to multiple loci |       0
             % of reads mapped to multiple loci |       0.00%
        Number of reads mapped to too many loci |       0
             % of reads mapped to too many loci |       0.00%
       % of reads unmapped: too many mismatches |       0.00%
                 % of reads unmapped: too short |       100.00%
                     % of reads unmapped: other |       0.00%
LOG
    """
}
