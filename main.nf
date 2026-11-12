#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { quantitate_DIANN } from './module/quantitate_DIANN.nf'
include { split_EasyPQPLibrary } from './module/split_EasyPQPLibrary.nf'
include { write_DIANNReportManifest } from './module/write_DIANNReportManifest.nf'
include { aggregate_DIANNQuantitation } from './module/aggregate_DIANNQuantitation.nf'

/** Resolve acquisitions and group them by fraction, keeping legacy two-column CSVs valid. */
def readSamples(String inputCsv) {
    def csv = file(inputCsv)
    Channel.fromPath(csv).splitCsv(header: true).toList().flatMap { rows ->
        if (!rows) error "Input CSV has no samples: ${csv}"
        if (!rows[0].containsKey('sample_name') || !rows[0].containsKey('path')) {
            error "${csv} must contain sample_name and path columns"
        }
        def fractionated = rows[0].containsKey('fraction_id')
        if (fractionated != params.library_has_fractions) {
            error 'fraction_id must be present in both the input CSV and EasyPQP library, or neither'
        }
        def pairs = [] as Set
        def names = [] as Set
        def paths = [] as Set
        def entries = rows.collect { row ->
            def sample = row.sample_name?.trim()
            def fraction = fractionated ? row.fraction_id?.trim() : 'unfractionated'
            if (!(sample ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) || sample in ['.', '..'] ||
                !(fraction ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) || fraction in ['.', '..']) {
                error "Invalid sample_name or fraction_id in ${csv}: ${sample}, ${fraction}"
            }
            if (!pairs.add("${sample}\t${fraction}")) error "Duplicate sample/fraction pair: ${sample}, ${fraction}"
            def rawPath = row.path?.trim()
            if (!rawPath) error "Missing acquisition path for ${sample}, ${fraction}"
            def acquisition = file(rawPath.startsWith('/') ? rawPath : "${csv.parent}/${rawPath}")
            if (!((acquisition.isFile() && acquisition.name.toLowerCase().endsWith('.mzml')) ||
                  (acquisition.isDirectory() && acquisition.name.toLowerCase().endsWith('.d')))) {
                error "Input must be an existing mzML file or Bruker .d directory: ${acquisition}"
            }
            if (!(acquisition.name ==~ /[A-Za-z0-9][A-Za-z0-9._-]*\.([mM][zZ][mM][lL]|[dD])/)) {
                error "Invalid acquisition name: ${acquisition.name}"
            }
            if (!names.add(acquisition.name.toLowerCase()) || !paths.add(acquisition.toRealPath().toString())) {
                error "Duplicate acquisition name or path: ${acquisition}"
            }
            [sample: sample, fraction: fraction, acquisition: acquisition]
        }
        def fastaPath = params.get('fasta')
        def references = [file(params.library)] + (fastaPath ? [file(fastaPath)] : [])
        entries.groupBy { it.fraction }.collect { fraction, group ->
            def ordered = group.sort { a, b -> a.sample <=> b.sample }
            tuple(fraction, params.dataset_id, references, ordered*.sample, ordered*.acquisition)
        }.sort { it[0] }
    }
}

log.info """\
        ===============================================
        Q U A N T I T A T E   P R O T E O M I C   D I A
        ===============================================
        Boutros Lab
        Pipeline: ${workflow.manifest.name} ${workflow.manifest.version}
        Library: ${params.library}
        FASTA: ${params.get('fasta') ?: 'none'}
        Samples: ${params.input_csv}
        Output: ${params.output_dir_base}
        DIA-NN image: ${params.docker_image_fragpipe}
        """.stripIndent()

workflow {
    def samples = readSamples(params.input_csv)
    if (params.library.toString().toLowerCase().endsWith('.tsv')) {
        def libraries = samples.map { fraction, dataset, references, names, acquisitions ->
            tuple(fraction, references[0])
        }
        split_EasyPQPLibrary(libraries)
        samples = samples.join(split_EasyPQPLibrary.out.prepared)
            .map { fraction, dataset, references, names, acquisitions, library ->
                tuple(fraction, dataset, [library] + references.drop(1), names, acquisitions)
            }
    }
    quantitate_DIANN(samples)
    if (params.library_has_fractions) {
        write_DIANNReportManifest(quantitate_DIANN.out.report_manifest.collect(flat: false),
                                  quantitate_DIANN.out.sample_manifest.collect(flat: false))
        aggregate_DIANNQuantitation(write_DIANNReportManifest.out.manifest)
    }
}
