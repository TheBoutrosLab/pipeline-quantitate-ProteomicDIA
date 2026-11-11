/** Compute sample-level quantities from all fraction reports. */
process aggregate_DIANNQuantitation {
    containerOptions params.project_script_mount_options
    container params.docker_image_diann_rpackage
    publishDir path: "${params.output_dir_base}/output/DIA-NN", mode: 'copy'

    input:
        tuple path(report_manifest), path(reports), path(acquisitions)

    output:
        path("${params.dataset_id}-report.*"), emit: matrices
        path('output.sha512'), emit: checksum

    script:
        """
        set -euo pipefail
        Rscript ${projectDir}/src/AggregateDIANNQuantitation.R \\
          --manifest ${report_manifest} --acquisitions ${acquisitions} \\
          --dataset-id ${params.dataset_id} --qvalue ${params['DIA-NN'].qvalue}
        sha512sum ${params.dataset_id}-report.tsv ${params.dataset_id}-report.*.tsv > output.sha512
        """
}
