# DIA-NN nf-test scaffold

Two integration cases are defined: `test-integration-DIANN` uses an EasyPQP TSV, while `test-integration-DIANN-predicted` uses a predicted `.speclib` and its source FASTA. The predicted case runs when selected; the TSV case remains skipped. No test data or assertions are bundled. To run the predicted case, copy `.env-template` to `.env`, set `TEST_DATA_DIR`. Set paths to real data. To enable the TSV case, add assertions and remove its `skip` setting in `nftest.yml`.

Inside a Slurm job, run `bash test/run-nftest.sh test-integration-DIANN-predicted` (or `test-integration-DIANN` for TSV). The runner writes outputs and work files under `/scratch/$SLURM_JOB_ID/<case>`.
