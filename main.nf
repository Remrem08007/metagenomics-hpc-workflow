#!/usr/bin/env nextflow

include { FASTQC } from './modules/fastqc'
include { FASTP } from './modules/fastp'
include { STAR_HOST_ALIGN } from './modules/star_host_depletion'
include { EXTRACT_NONHOST_PAIRS } from './modules/extract_nonhost_pairs'
include { KRAKEN2_CLASSIFY } from './modules/kraken2'
include { KAIJU_CLASSIFY } from './modules/kaiju'
include { MERGE_TAXONOMY } from './modules/merge_taxonomy'

params.input         = null
params.outdir        = 'results'
params.host_index    = null
params.kraken2_db    = null
params.kaiju_db      = null
params.kaiju_fmi     = 'kaiju_db.fmi'
params.container_dir = null


def requireParam(name, value) {
    if (!value) {
        error "Missing required parameter: --${name}"
    }
}


def requireAbsolutePath(name, value) {
    requireParam(name, value)
    if (!value.toString().startsWith('/')) {
        error "--${name} must be an absolute path: ${value}"
    }
}


def samplesheetChannel(String samplesheet) {
    return Channel
        .fromPath(samplesheet, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def sample = row.sample?.toString()?.trim()
            def r1 = row.fastq_1?.toString()?.trim()
            def r2 = row.fastq_2?.toString()?.trim()

            if (!sample || !r1 || !r2) {
                error "Samplesheet requires non-empty columns: sample,fastq_1,fastq_2"
            }
            if (sample.contains(' ')) {
                error "Sample identifiers may not contain spaces: '${sample}'"
            }

            tuple(
                [id: sample],
                file(r1, checkIfExists: true),
                file(r2, checkIfExists: true)
            )
        }
}

workflow {
    requireParam('input', params.input)
    requireAbsolutePath('host_index', params.host_index)
    requireAbsolutePath('kraken2_db', params.kraken2_db)
    requireAbsolutePath('kaiju_db', params.kaiju_db)
    requireAbsolutePath('container_dir', params.container_dir)

    samples_ch = samplesheetChannel(params.input)

    qc_ch = samples_ch.map { meta, r1, r2 -> tuple(meta, [r1, r2]) }
    FASTQC(qc_ch)

    FASTP(samples_ch)
    STAR_HOST_ALIGN(FASTP.out.reads, params.host_index)
    EXTRACT_NONHOST_PAIRS(STAR_HOST_ALIGN.out.bam)

    nonhost_ch = EXTRACT_NONHOST_PAIRS.out.reads
    KRAKEN2_CLASSIFY(nonhost_ch, params.kraken2_db)
    KAIJU_CLASSIFY(nonhost_ch, params.kaiju_db)

    taxonomy_ch = KRAKEN2_CLASSIFY.out.report
        .join(KAIJU_CLASSIFY.out.summary)
        .map { meta, kraken_report, kaiju_summary -> tuple(meta, kraken_report, kaiju_summary) }

    MERGE_TAXONOMY(taxonomy_ch)
}
