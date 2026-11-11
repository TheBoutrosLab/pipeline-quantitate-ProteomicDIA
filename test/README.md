# DIA-NN nf-test integration cases

Four cases are defined:

- `test-integration-DIANN-fractionated` quantifies two E. coli samples across fractions F1–F3 using the annotated EasyPQP cohort library produced by `generate-ProteomicSpectralLibrary-1.1.0`. Its CSV lives beside the test config and uses `$TEST_DATA_DIR` paths.
- `test-integration-DIANN-bruker` quantifies the original HeLa dia-PASEF `.d` acquisition against its generated EasyPQP TSV library. Its CSV lives beside the test config and points to the `.d` directory under `$TEST_DATA_DIR`. This case enables `copy_inputs_to_work` to read the acquisition from local scratch.
- `test-integration-DIANN-predicted` quantifies E. coli mzML files against a predicted `.speclib` and its source FASTA.
- `test-integration-DIANN` uses an E. coli EasyPQP TSV and remains skipped.

The fractionated, Bruker, and predicted cases run when selected. No test data or separate nf-test assertions are bundled; each case relies on the pipeline's checks for a nonempty DIA-NN main report and, for TSV input, recognized fragment types, charges, and neutral losses. Set `TEST_DATA_DIR` in `.env` (copied from `.env-template`) to the directory containing the test data. The Bruker and fractionated cases require the completed spectral-library outputs at the paths in their test configs.

Inside a Slurm job, run `bash test/run-nftest.sh test-integration-DIANN-bruker`. The runner writes outputs and work files under `/scratch/$SLURM_JOB_ID/<case>`.

The HeLa case also checks that DIA-NN accepts the staged EasyPQP library without a missing-fragment-annotation warning.
