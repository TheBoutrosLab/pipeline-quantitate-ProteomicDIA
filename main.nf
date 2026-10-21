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
        def mzmlNames = [] as Set
        def mzmlPaths = [] as Set
        def ordered = rows.collect { row ->
            if (row.keySet() != (['sample_name', 'mzML'] as Set)) {
                error "${csv} must have exactly sample_name,mzML columns"
            }
            def sampleName = row.sample_name?.trim()
            if (!(sampleName ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) || sampleName in ['.', '..']) {
                error "Invalid sample_name in ${csv}: ${row.sample_name}"
            }
            if (!sampleNames.add(sampleName)) {
                error "Duplicate sample_name in ${csv}: ${sampleName}; v1 accepts one mzML per sample"
            }
            def rawPath = row.mzML?.trim()
            if (!rawPath) {
                error "Missing mzML path for ${sampleName}"
            }
            def mzml = file(rawPath.startsWith('/') ? rawPath : "${csv.parent}/${rawPath}")
            if (!mzml.isFile() || !mzml.name.toLowerCase().endsWith('.mzml')) {
                error "Missing or invalid mzML for ${sampleName}: ${mzml}"
            }
            if (!(mzml.name ==~ /[A-Za-z0-9][A-Za-z0-9._-]*\.[mM][zZ][mM][lL]/)) {
                error "mzML filename must use letters, numbers, dots, underscores or hyphens: ${mzml.name}"
            }
            if (!mzmlNames.add(mzml.name.toLowerCase()) || !mzmlPaths.add(mzml.toRealPath().toString())) {
                error "Duplicate mzML name or path: ${mzml}"
            }
            [sampleName: sampleName, mzml: mzml]
        }.sort { it.sampleName }
        tuple(params.dataset_id, file(params.library_tsv), ordered*.sampleName, ordered*.mzml)
    }
}

log.info """\
        ===========================================
        Q U A N T I T A T E   P R O T E O M I C   D I A
        ===========================================
        Boutros Lab
        Pipeline: ${workflow.manifest.name} ${workflow.manifest.version}
        Library: ${params.library_tsv}
        Samples: ${params.input_csv}
        Output: ${params.output_dir_base}
        DIA-NN image: ${params.docker_image_fragpipe}
        """.stripIndent()

workflow {
    quantitate_DIANN(readSamples(params.input_csv))
}
