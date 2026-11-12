# Quantitate Proteomic DIA

This Nextflow DSL2 pipeline quantifies cohorts of DIA mzML files or Bruker `.d` directories with DIA-NN from the `fcyucn/fragpipe:24.0` image. It accepts either a cohort EasyPQP TSV from `pipeline-generate-ProteomicSpectralLibrary` or a DIA-NN `.speclib`, including a FASTA-predicted `.predicted.speclib`. DIA-NN processes all samples together within each fraction. Unfractionated cohorts retain DIA-NN's native output; an R aggregation step combines reports only for fractionated cohorts.

![Unfractionated and fractionated DIA-NN quantitation workflows](img/flow-diagram.svg?raw=true)

## How to run

Initialize Git submodules with `git submodule update --init --recursive`. Copy `config/template.config` to a run-specific config and set `dataset_id`, `input_csv`, `library`, and `output_dir`. Run with the Boutros Lab Nextflow submission tool or `nextflow run . -c your.config -profile docker`.

Set `library` to an EasyPQP `.tsv` or DIA-NN `.speclib`. For TSV input, the separate `split_EasyPQPLibrary` process creates a validated TSV with explicit `FragmentType`, `FragmentSeriesNumber`, `FragmentCharge`, and `FragmentLossType` columns derived from `Annotation` (for example, `y9^2` becomes type `y`, series number 9, charge 2, and `noloss`). Existing fragment annotation columns must agree with `Annotation`; unsupported or ambiguous annotations stop the run. The source library is unchanged. For an EasyPQP TSV, protein inference defaults to off (`--no-prot-inf`), retaining the library's protein groups. A `.predicted.speclib` requires the matching source `fasta`; protein inference defaults to on. For other `.speclib` libraries, FASTA is optional and protein inference also defaults to on. Set `no_prot_inf` in the `'DIA-NN'` namespace to override either default. The pipeline warns when `--no-prot-inf` is enabled for a predicted library, or when a TSV is supplied with FASTA or without `--no-prot-inf`. Setting `reannotate = true` requires FASTA and replaces protein annotations based on its sequences. Use the same sample CSV with either library to compare searches, but choose distinct `dataset_id` values or output roots so results do not overwrite each other.

```groovy
// Predicted library example
params {
    dataset_id = 'cohort-predicted'
    input_csv = '/data/samples.csv'
    library = '/data/cohort.predicted.speclib'
    fasta = '/data/source-proteins.fasta'
    output_dir = '/data/results'
}
```

The CSV requires `sample_name` and `path`. For fractionated cohorts it also requires `fraction_id`, with one acquisition per sample/fraction pair. Additional columns are allowed and ignored. Relative paths resolve from the CSV directory. Sample/fraction pairs and acquisition basenames must be unique. Basenames may contain letters, numbers, dots, underscores, and hyphens. Supply the original `.d` directory for dia-PASEF quantitation, even when library generation used a reconstructed mzML. For fractionated quantitation, the EasyPQP library must contain a `fraction_id` column. The pipeline prepares a separate library and runs DIA-NN once per fraction. The legacy two-column CSV remains valid with an unannotated library.

```csv
sample_name,path
sample_01,/data/sample_01.mzML
sample_02,/data/sample_02.d
```

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `dataset_id` | Yes | Cohort identifier and output name. |
| `input_csv` | Yes | Sample, optional fraction, and mzML or Bruker .d mapping. |
| `library` | Yes | Nonempty EasyPQP `.tsv` or DIA-NN `.speclib`. |
| `fasta` | For predicted libraries | Matching source FASTA; also required if reannotating. |
| `output_dir` | Yes | Output root. |
| `params { 'DIA-NN' { ... } }` | No | DIA-NN option namespace; each snake_case key maps directly to a `--kebab-case` flag. |
| `docker_image_fragpipe` | No | DIA-NN image, default `fcyucn/fragpipe:24.0`. |
| `docker_image_diann_rpackage` | No | R aggregation image; default `ghcr.io/theboutroslab/diann-rpackage:af538f6`. Override with the locally built image tag until publication. |
| `docker_image_pyopenms` | No | EasyPQP TSV preparation image, default `ghcr.io/theboutroslab/pyopenms:3.5.0`. |
| `copy_inputs_to_work` | No | Copy acquisitions and reference inputs into the task work directory before DIA-NN; default `false` uses symlinks. Useful for remote mounts, at the cost of transfer time and local disk space. |
| `work_dir` | No | Nextflow work directory. Prefer scratch space; large mzML and DIA-NN temporary files can consume substantial storage. |

## Outputs

Final results are published under `quantitate-ProteomicDIA-<version>/<dataset_id>/output/DIA-NN/`. For a two-column input CSV, DIA-NN quantifies the complete cohort directly. The pipeline publishes its native `<dataset_id>-report*` files, `diann.log`, and `output.sha512`; it does not run R aggregation.

For fractionated input, the R aggregation writes `<dataset_id>-report.tsv` with one row per sample and precursor, `.pr_matrix.tsv` and `.pg_matrix.tsv` matrices, modified- and stripped-peptide matrices, fraction coverage, and `output.sha512`. Gene-related matrices and fields are not part of the combined output. The report retains native non-gene DIA-NN columns in their original order. It sums `Precursor.Quantity`, `Precursor.Normalised`, `PG.Quantity`, and `PG.Normalised` across observed fractions and recalculates `PG.MaxLFQ` with the DIA-NN R package. Other native columns, including scores, RT, fragment metrics, and q-values, come from the lowest-q-value representative fraction and are identified by `Representative.Fraction.ID` and `Uncombined.Fields.Scope`. Native fraction-specific files remain intermediate Nextflow work files and are not published.

The default `params { 'DIA-NN' { ... } }` namespace reproduces FragPipe's q-value thresholds, matrices, profiling, quantification, and report options. For the TSV library, `no_prot_inf` defaults to `true`; for a `.speclib`, it defaults to `false`. Override individual keys in the run config:

```groovy
params {
    'DIA-NN' {
        qvalue = 0.01          // --qvalue 0.01
        no_prot_inf = false   // omit --no-prot-inf
        no_ifs_removal = false // omit --no-ifs-removal
        mass_acc = 10         // --mass-acc 10
        pg_level = 1          // --pg-level 1
    }
}
```

A `true` Boolean emits a flag; `false` omits it. A string or number emits a flag with that value. A list repeats the flag for each value, such as `var_mod = ['UniMod:35,15.994915,M', 'UniMod:21,79.966331,STY']` inside the namespace. Pipeline-managed file and execution options (`lib`, `fasta`, `f`, `dir`, `out`, `threads`, `cfg`) cannot be set here. Version-specific options must be supported by the DIA-NN binary in the selected image, and file-valued options must refer to paths visible inside the container. With `copy_inputs_to_work = true`, Nextflow copies all staged inputs, including `.d` directories, into the task work directory before DIA-NN runs. The pipeline writes these options, the staged library and FASTA paths, and all acquisitions to the work-directory `diann-input/filelist_diann.txt`, then invokes DIA-NN with only `--cfg diann-input/filelist_diann.txt--`. The bundled version may print `WARNING: unrecognised option [--]` while still loading the runs. For fractionated cohorts, the aggregation uses confident `Precursor.Normalised` observations, sums repeated precursor quantities across fractions, and applies `diann_maxlfq()` to sample-level precursor quantities. No additional cross-fraction intensity scaling is applied. The aggregated precursor and protein-group matrices use DIA-NN-compatible `.pr_matrix.tsv` and `.pg_matrix.tsv` suffixes and identifier columns, with biological sample names as quantity columns. They are published in `output/DIA-NN/` and remain custom estimates: the protein values come from the DIA-NN R package, not DIA-NN’s internal QuantUMS or MaxLFQ calculation.

## Testing

Active HeLa `.d` and predicted-library nf-test cases, plus a skipped E. coli TSV scaffold, are provided in `test/`. See `test/README.md`. Tests were not run locally for this change.

## References

- [DIA-NN command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference)
- [FragPipe DIA workflow](https://fragpipe.nesvilab.org/docs/tutorial_DIA.html)
- [EasyPQP](https://github.com/grosenberger/easypqp)

## License

Licensed under GNU GPL version 2; see `LICENSE`.
