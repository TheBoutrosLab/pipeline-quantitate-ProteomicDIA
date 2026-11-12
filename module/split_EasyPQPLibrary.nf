/** Select and annotate one fraction of an EasyPQP library. */
process split_EasyPQPLibrary {
    containerOptions params.project_script_mount_options
    container params.docker_image_pyopenms

    input:
        tuple val(fraction_id), path(library_tsv, stageAs: 'source-library.tsv')

    output:
        tuple val(fraction_id), path('library.tsv'), emit: prepared

    script:
        def fractionOption = params.library_has_fractions ? "--fraction-id '${fraction_id}'" : ''
        """
        set -euo pipefail
        python3 ${projectDir}/src/PrepareEasyPQPLibrary.py --input "${library_tsv}" --output library.tsv ${fractionOption}
        """
}
