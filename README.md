# Quantitate Proteomic DIA

This Nextflow DSL2 pipeline quantifies a cohort of unfractionated DIA mzML runs with DIA-NN from the `fcyucn/fragpipe:24.0` image. It uses the cohort EasyPQP TSV produced by `pipeline-generate-ProteomicSpectralLibrary`, downstream of MSFragger search and PSM validation. The library is supplied unchanged; DIA-NN retains its protein groups with `--no-prot-inf`. One DIA-NN invocation processes every sample in the cohort so cross-run quantities and matrices are calculated together.

## How to run

Initialize Git submodules with `git submodule update --init --recursive`. Copy `config/template.config` to a run-specific config and set `dataset_id`, `input_csv`, `library_tsv`, and `output_dir`. Run with the Boutros Lab Nextflow submission tool or `nextflow run . -c your.config -profile docker`.

The CSV has exactly `sample_name,mzML` columns, one mzML per biological sample. Relative mzML paths resolve from the CSV directory. Sample names and mzML filenames must be unique. mzML filenames may contain letters, numbers, dots, underscores, and hyphens. Fractions used earlier for library construction need not be listed. Fractionated quantification samples are outside the scope of this first version.

```csv
sample_name,mzML
sample_01,/data/sample_01.mzML
sample_02,/data/sample_02.mzML
```

## Parameters

| Parameter | Required | Description |
| --- | --- | --- |
| `dataset_id` | Yes | Cohort identifier and output name. |
| `input_csv` | Yes | Sample to mzML mapping. |
| `library_tsv` | Yes | Nonempty EasyPQP cohort library TSV. |
| `output_dir` | Yes | Output root. |
| `diann_qvalue` | No | Main report precursor q-value cutoff, default 0.01. |
| `diann_matrix_qvalue` | No | Matrix q-value cutoff, default 0.01. |
| `diann_fragment_interference_removal` | No | Remove interference from fragment elution curves when `true`; default `false` matches FragPipe (`--no-ifs-removal`). |
| `docker_image_fragpipe` | No | DIA-NN image, default `fcyucn/fragpipe:24.0`. |
| `work_dir` | No | Nextflow work directory. Prefer scratch space; large mzML and DIA-NN temporary files can consume substantial storage. |

## Outputs

Results are published directly under `quantitate-ProteomicDIA-1.0.0/<dataset_id>/output/DIA-NN/`: all DIA-NN files beginning with `<dataset_id>-report`, plus `diann.log` and `output.sha512`. The checksum file covers those published DIA-NN reports and `diann.log`. The generated input list, sample manifest, and library checksum stay in the Nextflow work directory. Nextflow logs and the effective parameter record are published under a timestamped `log-*` directory.

The main report is filtered at `diann_qvalue`. Matrices use `diann_matrix_qvalue`, so matrix counts need not equal main report counts. The DIA-NN command also follows FragPipe with `--smart-profiling`, `--no-quant-files`, `--peak-center`, and `--report-lib-info`. Fragment interference removal is disabled by default to match FragPipe and can be enabled with `diann_fragment_interference_removal = true`. The pipeline records staged mzML paths in a work-directory `filelist_diann.txt` and passes the file with FragPipe’s working `--cfg filelist_diann.txt--` syntax as the final DIA-NN option. This keeps the command length constant for large cohorts. The bundled DIA-NN version may print `WARNING: unrecognised option [--]` while still loading the runs. The library's protein groups are preserved; this pipeline does not perform fresh protein inference or merge fraction quantities.

## Testing

An intentionally skipped nf-test integration scaffold is provided in `test/`. See `test/README.md`. No local tests were run for this initial implementation.

## References

- [DIA-NN command-line reference](https://github.com/vdemichev/DiaNN#command-line-reference)
- [FragPipe DIA workflow](https://fragpipe.nesvilab.org/docs/tutorial_DIA.html)
- [EasyPQP](https://github.com/grosenberger/easypqp)

## License

Licensed under GNU GPL version 2; see `LICENSE`.
