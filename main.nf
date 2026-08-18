#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { FASTQC }                  from './modules/fastqc'
include { FASTP }                   from './modules/fastp'
include { STAR_HOST_ALIGN }         from './modules/star_host_depletion'
include { EXTRACT_NONHOST_PAIRS }   from './modules/extract_nonhost_pairs'
include { VALIDATE_STAR_DEPLETION } from './modules/validate_star_depletion'
include { KRAKEN2_CLASSIFY }        from './modules/kraken2'
include { VALIDATE_KRAKEN_HUMAN }   from './modules/validate_kraken_human'
include { KAIJU_CLASSIFY }          from './modules/kaiju'
include { MERGE_TAXONOMY }          from './modules/merge_taxonomy'
include { COLLECT_TAXONOMY }        from './modules/collect_taxonomy'


def requireParam(name, value) {
    if (value == null || value.toString().trim() == '') {
        error "Missing required parameter: --${name}"
    }
}


def requireAbsolutePath(name, value) {
    requireParam(name, value)
    if (!value.toString().startsWith('/')) {
        error "--${name} must be an absolute path: ${value}"
    }
}


def resolveReadPath(sheetDir, String value) {
    def raw = java.nio.file.Paths.get(value)
    def resolved = raw.isAbsolute() ? raw : sheetDir.resolve(raw).normalize()
    return file(resolved.toString(), checkIfExists: true)
}


def samplesheetChannel(String samplesheet) {
    def sheetPath = file(samplesheet, checkIfExists: true)
    def sheetDir = sheetPath.parent
    def seen = [] as Set

    return Channel
        .fromPath(sheetPath)
        .splitCsv(header: true)
        .map { row ->
            def sample = row.sample?.toString()?.trim()
            def r1 = row.fastq_1?.toString()?.trim()
            def r2 = row.fastq_2?.toString()?.trim()

            if (!sample || !r1 || !r2) {
                error "Samplesheet requires non-empty columns: sample,fastq_1,fastq_2"
            }
            if (!(sample ==~ /[A-Za-z0-9_.-]+/)) {
                error "Invalid sample identifier '${sample}'. Allowed: letters, numbers, '.', '_' and '-'."
            }
            if (!seen.add(sample)) {
                error "Duplicate sample identifier in samplesheet: '${sample}'"
            }

            tuple(
                [id: sample],
                resolveReadPath(sheetDir, r1),
                resolveReadPath(sheetDir, r2)
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

    raw_qc_ch = samples_ch.map { meta, r1, r2 -> tuple(meta, [r1, r2]) }
    FASTQC(raw_qc_ch)

    FASTP(samples_ch)
    STAR_HOST_ALIGN(FASTP.out.reads, params.host_index)
    EXTRACT_NONHOST_PAIRS(STAR_HOST_ALIGN.out.alignment)

    validator = file("${projectDir}/bin/validate_host_depletion.py", checkIfExists: true)
    VALIDATE_STAR_DEPLETION(EXTRACT_NONHOST_PAIRS.out.reads_with_log, validator)

    nonhost_ch = VALIDATE_STAR_DEPLETION.out.reads
    KRAKEN2_CLASSIFY(nonhost_ch, params.kraken2_db)
    KAIJU_CLASSIFY(nonhost_ch, params.kaiju_db)

    VALIDATE_KRAKEN_HUMAN(KRAKEN2_CLASSIFY.out.report, validator)

    kraken_species_ch = VALIDATE_KRAKEN_HUMAN.out.report
        .map { meta, kraken_report -> tuple(meta.id, meta, kraken_report) }

    kaiju_species_ch = KAIJU_CLASSIFY.out.summary
        .map { meta, kaiju_summary -> tuple(meta.id, kaiju_summary) }

    taxonomy_ch = kraken_species_ch
        .join(kaiju_species_ch)
        .map { sample_id, meta, kraken_report, kaiju_summary ->
            tuple(meta, kraken_report, kaiju_summary)
        }

    merge_script = file("${projectDir}/bin/merge_taxonomy.py", checkIfExists: true)
    MERGE_TAXONOMY(taxonomy_ch, merge_script)

    COLLECT_TAXONOMY(MERGE_TAXONOMY.out.table.map { meta, table -> table }.collect())
}
