/** Validate EasyPQP fragment annotations and produce a DIA-NN-compatible TSV. */
process prepare_EasyPQPLibrary {
    containerOptions params.project_script_mount_options
    container params.docker_image_pyopenms

    input:
        tuple val(dataset_id), path(library_tsv, stageAs: 'source-library.tsv')

    output:
        tuple val(dataset_id), path('library.tsv'), emit: prepared

    script:
        """
        set -euo pipefail
        python3 ${projectDir}/src/PrepareEasyPQPLibrary.py --input "${library_tsv}" --output library.tsv
        """
}
