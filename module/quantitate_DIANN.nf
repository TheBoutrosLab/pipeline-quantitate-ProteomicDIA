/** Quantify a cohort against one EasyPQP TSV or DIA-NN .speclib library. */
process quantitate_DIANN {
    container params.docker_image_fragpipe
    stageInMode params.copy_inputs_to_work ? 'copy' : 'symlink'
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy', enabled: !params.library_has_fractions, pattern: "${params.dataset_id}-report*"
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy', enabled: !params.library_has_fractions, pattern: 'diann.log'
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy', enabled: !params.library_has_fractions, pattern: 'output.sha512'
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy', enabled: !params.library_has_fractions, pattern: 'acquisitions.tsv'
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy', enabled: params.library_has_fractions, pattern: "${params.dataset_id}-*-diann.log"

    input:
        tuple val(fraction_id), val(dataset_id), path(references), val(sample_names), path(acquisitions)

    output:
        path("${fraction_id == 'unfractionated' ? dataset_id : dataset_id + '-' + fraction_id}-report*"), emit: native_reports
        path('diann.log'), emit: log
        path("${dataset_id}-${fraction_id}-diann.log"), optional: true, emit: fraction_log
        path('output.sha512'), emit: checksum
        tuple val(fraction_id), path("${fraction_id == 'unfractionated' ? dataset_id : dataset_id + '-' + fraction_id}-report.tsv"), emit: report_manifest
        tuple val(fraction_id), path('acquisitions.tsv'), emit: acquisition_manifest

    script:
        def outputPrefix = fraction_id == 'unfractionated' ? dataset_id : "${dataset_id}-${fraction_id}"
        def library = references[0]
        def fasta = references.size() > 1 ? references[1] : null
        // The DIA-NN executable receives a constant-length --cfg invocation.
        def shellQuote = { value -> "'" + value.toString().replace("'", "'\"'\"'") + "'" }
        def cfgValue = { value ->
            def token = value.toString()
            def needsQuote = token.contains(' ') || token.contains('\t') || token.contains('"') ||
                             token.contains("'") || token.contains('\\')
            needsQuote ? '"' + token.replace('\\', '\\\\').replace('"', '\\"') + '"' : token
        }
        def libraryName = params.library.toString().toLowerCase().endsWith('.speclib') ? 'library.speclib' : 'library.tsv'
        def libraryPreparation = "ln -s ${shellQuote('../' + library.name)} diann-input/${libraryName}"
        def fragmentAnnotationCheck = libraryName == 'library.tsv' ?
            "if grep -Eqi 'no fragment charge information found|fragment charge 0 specified|fragments with invalid/unspecified charges|no fragment type information found|no neutral loss information found' diann.log; then echo 'DIA-NN did not recognise fragment type, charge, or loss in the prepared library' >&2; exit 1; fi" : ''
        def cfgRows = [
            "--lib diann-input/${libraryName}",
            "--out ${outputPrefix}-report.tsv",
            "--threads ${task.cpus}"
        ]
        if (fasta) cfgRows << '--fasta diann-input/source.fasta'
        params['DIA-NN'].each { key, value ->
            def flag = '--' + key.replace('_', '-')
            def values = value instanceof List ? value : [value]
            values.each { item ->
                if (item instanceof Boolean) {
                    if (item) cfgRows << flag
                } else {
                    cfgRows << "${flag} ${cfgValue(item)}"
                }
            }
        }
        def cfgCommands = cfgRows.collect { "printf '%s\\n' ${shellQuote(it)} >> diann-input/filelist_diann.txt" }.join('\n')
        def filelistRows = acquisitions.collect {
            "printf '%s\\n' \"--f \$PWD/${it.name}\" >> diann-input/filelist_diann.txt"
        }.join('\n')
        def manifestRows = (0..<sample_names.size()).collect { i ->
            "printf '%s\\t%s\\t%s\\n' '${fraction_id}' '${sample_names[i]}' '${acquisitions[i].name}' >> acquisitions.tsv"
        }.join('\n')
        """
        set -euo pipefail
        mkdir -p diann-input
        printf 'fraction_id\\tsample_name\\tacquisition\\n' > acquisitions.tsv
        ${manifestRows}
        sha512sum ${shellQuote(library.name)} > diann-input/library.sha512
        ${fasta ? "sha512sum ${shellQuote(fasta.name)} > diann-input/fasta.sha512" : ''}
        ${libraryPreparation}
        ${fasta ? "ln -s ${shellQuote('../' + fasta.name)} diann-input/source.fasta" : ''}
        : > diann-input/filelist_diann.txt
        ${cfgCommands}
        ${filelistRows}
        test -s diann-input/filelist_diann.txt

        diann_bin=\$(find /fragpipe_bin -type f -iname 'diann*' -perm -111 -print -quit)
        if [ -z "\$diann_bin" ]; then
            echo 'DIA-NN executable was not found in the FragPipe image' >&2
            exit 1
        fi
        "\$diann_bin" --cfg diann-input/filelist_diann.txt-- > diann.log 2>&1 || {
                cat diann.log >&2
                exit 1
            }
        ${fragmentAnnotationCheck}
        if ! find . -maxdepth 1 -type f \\( -name '${outputPrefix}-report.tsv' -o -name '${outputPrefix}-report.parquet' \\) -size +0c | grep -q .; then
            echo 'DIA-NN completed without a nonempty main report; DIA-NN log follows:' >&2
            cat diann.log >&2
            echo 'Files in work directory:' >&2
            ls -lah . >&2
            exit 1
        fi
        if [ '${fraction_id}' != 'unfractionated' ]; then
            cp diann.log ${outputPrefix}-diann.log
        fi
        find . -maxdepth 1 -type f \\( -name '${outputPrefix}-report*' -o -name 'diann.log' -o -name 'acquisitions.tsv' \\) -print0 | sort -z | xargs -0 -r sha512sum > output.sha512
        """
}
