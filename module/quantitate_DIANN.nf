/** Quantify the complete cohort against one EasyPQP spectral library. */
process quantitate_DIANN {
    container params.docker_image_fragpipe

    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy'

    input:
        tuple val(dataset_id), path(library), val(sample_names), path(mzmls)

    output:
        path('diann-output'), emit: results

    script:
        def filelistRows = mzmls.collect {
            "printf '%s\\n' \"--f \$PWD/${it.name}\" >> diann-output/filelist_diann.txt"
        }.join('\n')
        def manifestRows = (0..<sample_names.size()).collect { i ->
            "printf '%s\\t%s\\n' '${sample_names[i]}' '${mzmls[i].name}' >> diann-output/samples.tsv"
        }.join('\n')
        """
        set -euo pipefail
        mkdir -p diann-output
        printf 'sample_name\\tmzML\\n' > diann-output/samples.tsv
        ${manifestRows}
        sha512sum '${library.name}' > diann-output/library.sha512
        : > diann-output/filelist_diann.txt
        ${filelistRows}
        test -s diann-output/filelist_diann.txt

        diann_bin=\$(find /fragpipe_bin -type f -iname 'diann*' -perm -111 -print -quit)
        if [ -z "\$diann_bin" ]; then
            echo 'DIA-NN executable was not found in the FragPipe image' >&2
            exit 1
        fi
        "\$diann_bin" --lib '${library.name}' \\
            --out 'diann-output/${dataset_id}-report.tsv' \\
            --threads ${task.cpus} \\
            --verbose 1 \\
            --qvalue ${params.diann_qvalue} \\
            --matrix-qvalue ${params.diann_matrix_qvalue} \\
            --matrices \\
            --no-prot-inf \\
            --smart-profiling \\
            --no-quant-files \\
            --peak-center \\
            --no-ifs-removal \\
            --report-lib-info \\
            --cfg diann-output/filelist_diann.txt-- > diann-output/diann.log 2>&1 || {
                cat diann-output/diann.log >&2
                exit 1
            }
        if ! find diann-output -maxdepth 1 -type f \\( -name '${dataset_id}-report.tsv' -o -name '${dataset_id}-report.parquet' \\) -size +0c | grep -q .; then
            echo 'DIA-NN completed without a nonempty main report; DIA-NN log follows:' >&2
            cat diann-output/diann.log >&2
            echo 'Files in DIA-NN output directory:' >&2
            ls -lah diann-output >&2
            exit 1
        fi
        find diann-output -maxdepth 1 -type f ! -name '*.sha512' -print0 | sort -z | xargs -0 -r sha512sum > diann-output/output.sha512
        """
}
