/** Collect fraction reports into a stable manifest for R aggregation. */
process write_DIANNReportManifest {
    input:
        val(report_pairs)
        val(sample_pairs)

    output:
        tuple path('diann-reports.csv'), path('reports/*'), path('acquisitions.tsv'), emit: manifest

    script:
        def rows = report_pairs.sort { it[0] }.collect { pair ->
            def fraction = pair[0]
            def report = pair[1].toString()
            def reportName = new File(report).name
            "cp '${report}' 'reports/${reportName}'; printf '%s,%s\\n' '${fraction}' '${reportName}' >> diann-reports.csv"
        }.join('\n')
        def sampleRows = sample_pairs.sort { it[0] }.collect { pair ->
            "tail -n +2 '${pair[1]}' | awk -F '\\t' -v f='${pair[0]}' 'BEGIN {OFS=\"\\t\"} {print f,\$1,\$2}' >> acquisitions.tsv"
        }.join('\n')
        """
        set -euo pipefail
        mkdir reports
        printf 'fraction_id,report_tsv\\n' > diann-reports.csv
        ${rows}
        printf 'fraction_id\\tsample_name\\tacquisition\\n' > acquisitions.tsv
        ${sampleRows}
        """
}
