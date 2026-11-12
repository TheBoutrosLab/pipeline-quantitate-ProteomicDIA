#!/usr/bin/env Rscript

# Combine DIA-NN reports from independent fraction searches into sample-level
# precursor, peptide, and protein-group quantities.
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(diann))


#' Parse command-line arguments from the Nextflow aggregation process.
#'
#' @param arguments Character vector of command-line tokens.
#' @return Named list containing input paths, dataset ID, and q-value.
parse_arguments <- function(arguments) {
    flags <- c("--manifest", "--acquisitions", "--dataset-id", "--qvalue")
    if (length(arguments) != 8L || !identical(arguments[c(1, 3, 5, 7)], flags)) {
        stop(paste(
            "Usage: AggregateDIANNQuantitation.R",
            "--manifest FILE --acquisitions FILE --dataset-id DATASET_ID --qvalue Q"
        ))
    }

    qvalue <- suppressWarnings(as.numeric(arguments[8]))
    if (length(qvalue) != 1L || !is.finite(qvalue) || qvalue <= 0 || qvalue > 1) {
        stop("Q-value must be a number in (0, 1]")
    }

    list(
        manifest     = arguments[2],
        acquisitions = arguments[4],
        dataset_id   = arguments[6],
        qvalue       = qvalue
    )
}


#' Convert acquisition paths or DIA-NN Run values to matching run keys.
#'
#' @param path Character vector of acquisition paths or run names.
#' @return Character vector without the .mzML or .d suffix.
run_key <- function(path) {
    sub("\\.(mzML|d)$", "", basename(path), ignore.case = TRUE)
}


#' Read and validate the report and acquisition manifests.
#'
#' @param report_path Path to the fraction-to-report CSV.
#' @param acquisition_path Path to the fraction-to-sample TSV.
#' @return List containing validated manifest and acquisition data tables.
read_manifests <- function(report_path, acquisition_path) {
    manifest     <- fread(report_path)
    acquisitions <- fread(acquisition_path)

    report_columns      <- c("fraction_id", "report_tsv")
    acquisition_columns <- c("fraction_id", "sample_name", "acquisition")
    if (!all(report_columns %in% names(manifest)) ||
            !all(acquisition_columns %in% names(acquisitions))) {
        stop("Report or acquisition manifest lacks required columns")
    }
    if (!nrow(manifest) || !nrow(acquisitions)) {
        stop("Report and acquisition manifests must be nonempty")
    }
    if (anyNA(manifest[, ..report_columns]) ||
            anyNA(acquisitions[, ..acquisition_columns])) {
        stop("Report and acquisition manifests cannot contain missing mappings")
    }
    if (anyDuplicated(manifest$fraction_id) ||
            anyDuplicated(acquisitions[, .(fraction_id, sample_name)]) ||
            anyDuplicated(acquisitions$acquisition)) {
        stop("Duplicate fraction or acquisition mapping")
    }
    if (!setequal(manifest$fraction_id, acquisitions$fraction_id)) {
        stop("Fraction IDs in report and acquisition manifests differ")
    }

    acquisitions[, Run.Key := run_key(acquisition)]
    if (anyDuplicated(acquisitions[, .(fraction_id, Run.Key)])) {
        stop("Ambiguous DIA-NN run names")
    }

    list(manifest = manifest, acquisitions = acquisitions)
}


#' Locate a staged DIA-NN report.
#'
#' @param manifest_path Path to the staged report manifest.
#' @param filename Report basename recorded in the manifest.
#' @return Path to the existing report file.
report_file <- function(manifest_path, filename) {
    base <- dirname(manifest_path)
    candidates <- file.path(base, c(filename, file.path("reports", filename)))
    available <- candidates[file.exists(candidates)]
    if (!length(available)) stop(sprintf("Report file not found: %s", filename))
    available[1]
}


#' Read a fraction report and map its DIA-NN runs to biological samples.
#'
#' @param row One-row data table from the report manifest.
#' @param manifest_path Path to the staged report manifest.
#' @param acquisitions Validated acquisition mapping data table.
#' @return Report data table with fraction_id and sample_name columns.
read_fraction_report <- function(row, manifest_path, acquisitions) {
    file <- report_file(manifest_path, row$report_tsv)
    report <- fread(file)
    # Gene annotations are excluded from custom cross-fraction output.
    native_columns <- names(report)[!grepl("^(Genes($|\\.)|GG\\.)", names(report))]
    required <- c(
        "Run", "Precursor.Id", "Precursor.Normalised", "Protein.Group",
        "Q.Value", "Modified.Sequence", "Stripped.Sequence", "Precursor.Charge"
    )
    missing <- setdiff(required, names(report))
    if (length(missing)) {
        stop(sprintf("Report %s lacks: %s", file, paste(missing, collapse = ", ")))
    }

    report[, fraction_id := row$fraction_id]
    report[, Run.Key := run_key(Run)]
    report <- merge(
        report,
        acquisitions[, .(fraction_id, Run.Key, sample_name)],
        by    = c("fraction_id", "Run.Key"),
        all.x = TRUE,
        sort  = FALSE
    )
    if (anyNA(report$sample_name)) {
        stop(sprintf("Unmapped DIA-NN run in %s", file))
    }
    attr(report, "native_columns") <- native_columns
    report
}


#' Retain confident precursor observations with positive normalized quantity.
#'
#' Missing and nonpositive quantities remain absent rather than becoming zero.
#'
#' @param observations Combined DIA-NN report data table.
#' @param qvalue Maximum accepted precursor and protein-group q-value.
#' @return Filtered observations with a numeric Quantity column.
filter_observations <- function(observations, qvalue) {
    observations <- observations[!is.na(Q.Value) & Q.Value <= qvalue]
    if ("PG.Q.Value" %in% names(observations)) {
        observations <- observations[!is.na(PG.Q.Value) & PG.Q.Value <= qvalue]
    }
    observations[, Quantity := as.numeric(Precursor.Normalised)]
    observations <- observations[is.finite(Quantity) & Quantity > 0]
    if (!nrow(observations)) {
        stop("No positive, confident precursor observations remain")
    }
    observations
}


#' Validate precursor annotations across fraction reports.
#'
#' A precursor cannot be summed if its peptide or protein assignment changes.
#'
#' @param observations Filtered precursor observations.
#' @return Invisibly returns NULL; raises an error for inconsistent mappings.
validate_precursor_mapping <- function(observations) {
    mapping_columns <- c(
        "Protein.Group", "Modified.Sequence", "Stripped.Sequence", "Precursor.Charge"
    )
    for (column in mapping_columns) {
        mapping <- unique(observations[, c("Precursor.Id", column), with = FALSE])
        if (anyDuplicated(mapping$Precursor.Id)) {
            stop(sprintf("Inconsistent %s for a precursor", column))
        }
    }
    invisible(NULL)
}


#' Aggregate precursor quantities within and across fractions.
#'
#' Repeated rows within one fraction use their maximum quantity. Quantities for
#' observed fractions of the same sample and precursor are then summed.
#'
#' @param observations Filtered precursor observations.
#' @return List with per_fraction and sample-level precursors data tables.
aggregate_precursors <- function(observations) {
    per_fraction <- observations[
        , .(Quantity = max(Quantity)),
        by = .(
            sample_name, fraction_id, Precursor.Id, Protein.Group,
            Modified.Sequence, Stripped.Sequence, Precursor.Charge
        )
    ]
    precursors <- per_fraction[
        , .(
            Quantity           = sum(Quantity),
            Fractions.Observed = uniqueN(fraction_id)
        ),
        by = .(
            sample_name, Precursor.Id, Protein.Group,
            Modified.Sequence, Stripped.Sequence, Precursor.Charge
        )
    ]
    list(precursors = precursors, per_fraction = per_fraction)
}


#' Aggregate one native quantity across the observed fractions of a sample.
#'
#' Repeated precursor rows contain the same group quantity within a run. Take
#' one value per sample/fraction/group before summing, avoiding double counts.
#'
#' @param observations Filtered native DIA-NN observations.
#' @param grouping Column identifying the quantified precursor or group.
#' @param column Native quantity column to aggregate.
#' @return Data table with sample, group, and aggregated Quantity.
aggregate_native_quantity <- function(observations, grouping, column) {
    valid <- observations[is.finite(as.numeric(get(column)))]
    per_fraction <- valid[
        , .(Quantity = max(as.numeric(get(column)))),
        by = c("sample_name", "fraction_id", grouping)
    ]
    per_fraction[
        , .(Quantity = sum(Quantity)),
        by = c("sample_name", grouping)
    ]
}


#' Build a native-shaped report with one row per sample and precursor.
#'
#' Every source column is retained in the source order. A representative
#' fraction supplies run-specific scores, RT, and other fields that cannot be
#' meaningfully combined. The lowest-Q.Value observation is selected; the
#' appended scope columns make its provenance explicit.
#'
#' @param observations Filtered native DIA-NN observations.
#' @param quantities Output from aggregate_precursors().
#' @param protein_matrix Wide matrix of custom protein-group MaxLFQ estimates.
#' @param native_columns Original DIA-NN report column names in order.
#' @return Data table with aggregated quantities and native report columns.
build_sample_report <- function(observations, quantities,
                                protein_matrix, native_columns) {
    setorder(observations, Q.Value, -Quantity)
    report <- copy(unique(observations, by = c("sample_name", "Precursor.Id")))
    report[, Representative.Fraction.ID := fraction_id]
    report[, Run := sample_name]

    # Keep native non-gene fields and remove internal routing fields.
    gene_columns <- grep("^(Genes($|\\.)|GG\\.)", names(report), value = TRUE)
    report[, c("fraction_id", "Run.Key", "sample_name", "Quantity",
               gene_columns) := NULL]
    report[, sample_name := Run]
    precursors <- quantities$precursors
    report[
        precursors,
        `:=`(
            Precursor.Normalised = i.Quantity,
            Fractions.Observed   = i.Fractions.Observed
        ),
        on = .(sample_name, Precursor.Id)
    ]
    if ("Precursor.Quantity" %in% native_columns) {
        totals <- aggregate_native_quantity(
            observations, "Precursor.Id", "Precursor.Quantity"
        )
        report[totals, Precursor.Quantity := i.Quantity,
               on = .(sample_name, Precursor.Id)]
    }
    for (column in c("PG.Quantity", "PG.Normalised")) {
        if (column %in% native_columns) {
            totals <- aggregate_native_quantity(
                observations, "Protein.Group", column
            )
            report[totals, (column) := i.Quantity,
                   on = .(sample_name, Protein.Group)]
        }
    }


    # DIA-NN's internal PG.MaxLFQ cannot be reproduced after separate jobs.
    # Replace it with the documented DIA-NN R-package MaxLFQ estimate.
    protein_long <- melt(
        protein_matrix,
        id.vars       = "Protein.Group",
        variable.name = "sample_name",
        value.name    = "PG.MaxLFQ"
    )
    report[protein_long, PG.MaxLFQ := i.PG.MaxLFQ,
           on = .(sample_name, Protein.Group)]

    fractions <- quantities$per_fraction[
        , .(Fraction.IDs = paste(sort(unique(fraction_id)), collapse = ";")),
        by = .(sample_name, Precursor.Id)
    ]
    report[fractions, Fraction.IDs := i.Fraction.IDs,
           on = .(sample_name, Precursor.Id)]
    confidence <- observations[
        , .(
            Best.Fraction.Q.Value  = min(Q.Value),
            Worst.Fraction.Q.Value = max(Q.Value)
        ),
        by = .(sample_name, Precursor.Id)
    ]
    report[confidence, `:=`(
        Best.Fraction.Q.Value  = i.Best.Fraction.Q.Value,
        Worst.Fraction.Q.Value = i.Worst.Fraction.Q.Value
    ), on = .(sample_name, Precursor.Id)]

    report[, `:=`(
        Protein.Quantification.Method = "diann-rpackage MaxLFQ",
        Uncombined.Fields.Scope           = "representative fraction"
    )]
    report[, sample_name := NULL]
    additions <- setdiff(names(report), native_columns)
    setcolorder(report, c(native_columns, additions))
    report
}


#' Sum sample-level precursor quantities by peptide sequence.
#'
#' @param precursors Sample-level precursor quantity data table.
#' @param sequence_column Peptide identifier column to aggregate by.
#' @return Long data table with one quantity per sample and peptide.
calculate_peptide_quantities <- function(precursors, sequence_column) {
    precursors[
        , .(Quantity = sum(Quantity)),
        by = c("sample_name", sequence_column)
    ]
}


#' Estimate sample-level protein-group quantities with the DIA-NN MaxLFQ package.
#'
#' Values are custom MaxLFQ estimates; the output schema matches DIA-NN's
#' protein-group matrix for downstream compatibility.
#'
#' @param precursors Sample-level precursor quantity data table.
#' @return Wide data table with one row per protein group and one column per sample.
calculate_protein_quantities <- function(precursors) {
    input <- precursors[
        Protein.Group != "",
        .(sample_name, Protein.Group, Precursor.Id, Quantity)
    ]
    if (!nrow(input)) stop("No protein groups remain for MaxLFQ")

    estimates <- diann_maxlfq(
        input,
        sample.header   = "sample_name",
        group.header    = "Protein.Group",
        id.header       = "Precursor.Id",
        quantity.header = "Quantity"
    )
    proteins <- as.data.table(estimates, keep.rownames = "Protein.Group")
    proteins
}


#' Summarize observed precursor coverage and signal for each sample fraction.
#'
#' DIA-NN normalizes runs within each fraction; no further scaling is applied.
#'
#' @param per_fraction Fraction-level precursor quantity data table.
#' @return Data table of precursor counts and total quantities by sample/fraction.
summarize_fraction_coverage <- function(per_fraction) {
    per_fraction[
        , .(
            Precursors.Observed      = uniqueN(Precursor.Id),
            Total.Precursor.Quantity = sum(Quantity)
        ),
        by = .(sample_name, fraction_id)
    ]
}


#' Reshape long sample quantities into a sample-by-feature matrix.
#'
#' Unobserved sample and feature combinations remain missing values.
#'
#' @param quantities Data table with sample_name and Quantity columns.
#' @param identifiers Character vector of feature identifier columns.
#' @return Wide data table with one column per observed sample.
to_sample_matrix <- function(quantities, identifiers) {
    formula <- as.formula(paste(paste(identifiers, collapse = " + "), "~ sample_name"))
    dcast(quantities, formula, value.var = "Quantity", fill = NA_real_)
}


#' Write a completed table to a tab-separated file.
#'
#' @param table Data table whose values are already calculated.
#' @param filename Output TSV path.
#' @return Invisibly returns the output filename.
write_table <- function(table, filename) {
    fwrite(table, filename, sep = "\t", na = "")
    invisible(filename)
}


#' Run validation, aggregation, and output generation.
#'
#' @return Invisibly returns NULL after writing all output tables.
main <- function() {
    options <- parse_arguments(commandArgs(trailingOnly = TRUE))
    inputs  <- read_manifests(options$manifest, options$acquisitions)
    reports <- lapply(seq_len(nrow(inputs$manifest)), function(index) {
        read_fraction_report(
            inputs$manifest[index],
            options$manifest,
            inputs$acquisitions
        )
    })
    native_columns <- attr(reports[[1]], "native_columns")
    if (!all(vapply(reports, function(report) {
        identical(attr(report, "native_columns"), native_columns)
    }, logical(1)))) {
        stop("Fraction DIA-NN reports have different native column schemas")
    }
    observations <- rbindlist(reports, fill = TRUE)
    if (!nrow(observations)) stop("All DIA-NN reports are empty")

    observations <- filter_observations(observations, options$qvalue)
    validate_precursor_mapping(observations)
    quantities <- aggregate_precursors(observations)

    protein_matrix <- calculate_protein_quantities(quantities$precursors)
    sample_report <- build_sample_report(
        observations, quantities, protein_matrix, native_columns
    )
    precursor_matrix <- to_sample_matrix(
        quantities$precursors,
        c("Protein.Group", "Stripped.Sequence", "Modified.Sequence", "Precursor.Charge")
    )
    modified_peptides <- calculate_peptide_quantities(
        quantities$precursors, "Modified.Sequence"
    )
    stripped_peptides <- calculate_peptide_quantities(
        quantities$precursors, "Stripped.Sequence"
    )
    modified_matrix <- to_sample_matrix(modified_peptides, "Modified.Sequence")
    stripped_matrix <- to_sample_matrix(stripped_peptides, "Stripped.Sequence")
    coverage       <- summarize_fraction_coverage(quantities$per_fraction)

    report_prefix <- paste0(options$dataset_id, "-report")
    write_table(sample_report, paste0(report_prefix, ".tsv"))
    write_table(precursor_matrix, paste0(report_prefix, ".pr_matrix.tsv"))
    write_table(modified_matrix, paste0(report_prefix, ".modified_peptide_matrix.tsv"))
    write_table(stripped_matrix, paste0(report_prefix, ".stripped_peptide_matrix.tsv"))
    write_table(protein_matrix, paste0(report_prefix, ".pg_matrix.tsv"))
    write_table(coverage, paste0(report_prefix, ".fraction_coverage.tsv"))
    invisible(NULL)
}


main()
