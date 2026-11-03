# Quantitate Proteomic DIA

This Nextflow DSL2 pipeline quantifies a cohort of unfractionated DIA mzML files or Bruker `.d` directories with DIA-NN from the `fcyucn/fragpipe:24.0` image. It accepts either a cohort EasyPQP TSV from `pipeline-generate-ProteomicSpectralLibrary` or a DIA-NN `.speclib`, including a FASTA-predicted `.predicted.speclib`. One DIA-NN invocation processes all samples so cross-run quantities and matrices are calculated together.

## How to run

Initialize Git submodules with `git submodule update --init --recursive`. Copy `config/template.config` to a run-specific config and set `dataset_id`, `input_csv`, `library`, and `output_dir`. Run with the Boutros Lab Nextflow submission tool or `nextflow run . -c your.config -profile docker`.

Set `library` to an EasyPQP `.tsv` or DIA-NN `.speclib`. For an EasyPQP TSV, protein inference defaults to off (`--no-prot-inf`), retaining the library's protein groups. A `.predicted.speclib` requires the matching source `fasta`; protein inference defaults to on. For other `.speclib` libraries, FASTA is optional and protein inference also defaults to on. Set `no_prot_inf` in the `'DIA-NN'` namespace to override either default. The pipeline warns when `--no-prot-inf` is enabled for a predicted library, or when a TSV is supplied with FASTA or without `--no-prot-inf`. Setting `reannotate = true` requires FASTA and replaces protein annotations based on its sequences. Use the same sample CSV with either library to compare searches, but choose distinct `dataset_id` values or output roots so results do not overwrite each other.

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

The CSV requires `sample_name` and `path` columns, one mzML file or Bruker `.d` directory per biological sample. Additional columns are allowed and ignored. Relative paths resolve from the CSV directory. Sample names and acquisition basenames must be unique. Basenames may contain letters, numbers, dots, underscores, and hyphens. Supply the original `.d` directory for dia-PASEF quantitation, even when library generation used a reconstructed mzML. Fractions used earlier for library construction need not be listed. Fractionated quantification samples are outside the scope of this first version.

```csv
sample_name,path
sample_01,/data/sample_01.mzML
sample_02,/data/sample_02.d
```

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `dataset_id` | Yes | Cohort identifier and output name. |
| `input_csv` | Yes | Sample to mzML or Bruker .d mapping. |
| `library` | Yes | Nonempty EasyPQP `.tsv` or DIA-NN `.speclib`. |
| `fasta` | For predicted libraries | Matching source FASTA; also required if reannotating. |
| `output_dir` | Yes | Output root. |
| `params { 'DIA-NN' { ... } }` | No | DIA-NN option namespace; each snake_case key maps directly to a `--kebab-case` flag. |
| `docker_image_fragpipe` | No | DIA-NN image, default `fcyucn/fragpipe:24.0`. |
| `copy_inputs_to_work` | No | Copy acquisitions and reference inputs into the task work directory before DIA-NN; default `false` uses symlinks. Useful for remote mounts, at the cost of transfer time and local disk space. |
| `work_dir` | No | Nextflow work directory. Prefer scratch space; large mzML and DIA-NN temporary files can consume substantial storage. |

## Outputs

Results are published directly under `quantitate-ProteomicDIA-1.0.0/<dataset_id>/output/DIA-NN/`: all DIA-NN files beginning with `<dataset_id>-report`, plus `diann.log`, `output.sha512`, and a `<dataset_id>-samples.tsv` manifest mapping sample names to staged acquisitions. The checksum file covers the published reports, manifest, and `diann.log`. The generated input list and library checksum stay in the Nextflow work directory. Nextflow logs and the effective parameter record are published under a timestamped `log-*` directory.

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

A `true` Boolean emits a flag; `false` omits it. A string or number emits a flag with that value. A list repeats the flag for each value, such as `var_mod = ['UniMod:35,15.994915,M', 'UniMod:21,79.966331,STY']` inside the namespace. Pipeline-managed file and execution options (`lib`, `fasta`, `f`, `dir`, `out`, `threads`, `cfg`) cannot be set here. Version-specific options must be supported by the DIA-NN binary in the selected image, and file-valued options must refer to paths visible inside the container. With `copy_inputs_to_work = true`, Nextflow copies all staged inputs, including `.d` directories, into the task work directory before DIA-NN runs. The pipeline writes these options, the staged library and FASTA paths, and all acquisitions to the work-directory `diann-input/filelist_diann.txt`, then invokes DIA-NN with only `--cfg diann-input/filelist_diann.txt--`. The bundled version may print `WARNING: unrecognised option [--]` while still loading the runs. This pipeline does not merge fraction quantities.

## Testing

Active HeLa `.d` and predicted-library nf-test cases, plus a skipped E. coli TSV scaffold, are provided in `test/`. See `test/README.md`. Tests were not run locally for this change.

## References

- [DIA-NN command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference)
- [FragPipe DIA workflow](https://fragpipe.nesvilab.org/docs/tutorial_DIA.html)
- [EasyPQP](https://github.com/grosenberger/easypqp)

## License

Licensed under GNU GPL version 2; see `LICENSE`.
