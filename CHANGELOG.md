# Changelog

## 1.0.0

- Add cohort-wide DIA-NN quantification from an EasyPQP spectral library and one mzML per sample.
- Add Boutros Lab configuration, input validation, output records, and a skipped nf-test integration scaffold.
- Align DIA-NN options with FragPipe quantification, including matrix q-value, profiling, quantification, and library information flags.
- Use FragPipe’s verified trailing `--cfg filelist_diann.txt--` syntax to load cohort runs from a file while keeping the command length constant.
- Record staged mzML runs in `filelist_diann.txt` within the work directory.
- Make DIA-NN fragment interference removal configurable, disabled by default to match FragPipe.
- Publish only dataset-prefixed DIA-NN reports, `diann.log`, and `output.sha512` directly in the DIA-NN output directory.
