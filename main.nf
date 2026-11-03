#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { quantitate_DIANN } from './module/quantitate_DIANN.nf'

/** One unfractionated DIA acquisition per biological sample. */
def readSamples(String inputCsv) {
    def csv = file(inputCsv)
    Channel.fromPath(csv).splitCsv(header: true).toList().map { rows ->
        if (!rows) {
            error "Input CSV has no samples: ${csv}"
        }
        def sampleNames = [] as Set
        def acquisitionNames = [] as Set
        def acquisitionPaths = [] as Set
        def ordered = rows.collect { row ->
            if (!row.containsKey('sample_name') || !row.containsKey('path')) {
                error "${csv} must contain sample_name and path columns"
            }
            def sampleName = row.sample_name?.trim()
            if (!(sampleName ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) || sampleName in ['.', '..']) {
                error "Invalid sample_name in ${csv}: ${row.sample_name}"
            }
            if (!sampleNames.add(sampleName)) {
                error "Duplicate sample_name in ${csv}: ${sampleName}; one acquisition is allowed per sample"
            }
            def rawPath = row.path?.trim()
            if (!rawPath) {
                error "Missing acquisition path for ${sampleName}"
            }
            def acquisition = file(rawPath.startsWith('/') ? rawPath : "${csv.parent}/${rawPath}")
            if (!((acquisition.isFile() && acquisition.name.toLowerCase().endsWith('.mzml')) ||
                  (acquisition.isDirectory() && acquisition.name.toLowerCase().endsWith('.d')))) {
                error "Input for ${sampleName} must be an existing mzML file or Bruker .d directory: ${acquisition}"
            }
            if (!(acquisition.name ==~ /[A-Za-z0-9][A-Za-z0-9._-]*\.([mM][zZ][mM][lL]|[dD])/)) {
                error "Acquisition name must use letters, numbers, dots, underscores or hyphens: ${acquisition.name}"
            }
            if (!acquisitionNames.add(acquisition.name.toLowerCase()) || !acquisitionPaths.add(acquisition.toRealPath().toString())) {
                error "Duplicate acquisition name or path: ${acquisition}"
            }
            [sampleName: sampleName, acquisition: acquisition]
        }.sort { it.sampleName }
        def fastaPath = params.get('fasta')
        def references = [file(params.library)] + (fastaPath ? [file(fastaPath)] : [])
        tuple(params.dataset_id, references, ordered*.sampleName, ordered*.acquisition)
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
    quantitate_DIANN(readSamples(params.input_csv))
}
