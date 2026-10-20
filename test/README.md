# DIA-NN nf-test scaffold

The integration case is intentionally empty and skipped. No test data or assertions are bundled. To enable it, copy `.env-template` to `.env`, set `TEST_DATA_DIR`, replace the paths in `test/test-integration-DIANN/input.csv` and `test/test-integration-DIANN/test.config`, add assertions, and change `skip` to `false` in `nftest.yml`.

Inside a Slurm job, run `bash test/run-nftest.sh test-integration-DIANN`. The runner writes outputs and work files under `/scratch/$SLURM_JOB_ID/test-integration-DIANN`.
