/** Quantify a cohort against one EasyPQP TSV or DIA-NN .speclib library. */
process quantitate_DIANN {
    container params.docker_image_fragpipe

    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy'

    input:
        tuple val(dataset_id), path(references), val(sample_names), path(mzmls)

    output:
        path("${dataset_id}-report*"), emit: reports
        path('diann.log'), emit: log
        path('output.sha512'), emit: checksum

    script:
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
        def cfgRows = [
            "--lib diann-input/${libraryName}",
            "--out ${dataset_id}-report.tsv",
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
        def filelistRows = mzmls.collect {
            "printf '%s\\n' \"--f \$PWD/${it.name}\" >> diann-input/filelist_diann.txt"
        }.join('\n')
        def manifestRows = (0..<sample_names.size()).collect { i ->
            "printf '%s\\t%s\\n' '${sample_names[i]}' '${mzmls[i].name}' >> diann-input/samples.tsv"
        }.join('\n')
        """
        set -euo pipefail
        mkdir -p diann-input
        printf 'sample_name\\tmzML\\n' > diann-input/samples.tsv
        ${manifestRows}
        sha512sum ${shellQuote(library.name)} > diann-input/library.sha512
        ${fasta ? "sha512sum ${shellQuote(fasta.name)} > diann-input/fasta.sha512" : ''}
        ln -s ${shellQuote('../' + library.name)} diann-input/${libraryName}
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
        if ! find . -maxdepth 1 -type f \\( -name '${dataset_id}-report.tsv' -o -name '${dataset_id}-report.parquet' \\) -size +0c | grep -q .; then
            echo 'DIA-NN completed without a nonempty main report; DIA-NN log follows:' >&2
            cat diann.log >&2
            echo 'Files in work directory:' >&2
            ls -lah . >&2
            exit 1
        fi
        find . -maxdepth 1 -type f \\( -name '${dataset_id}-report*' -o -name 'diann.log' \\) -print0 | sort -z | xargs -0 -r sha512sum > output.sha512
        """
}
