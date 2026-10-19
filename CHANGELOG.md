# Changelog

## Unreleased

- Use FragPipe’s verified trailing `--cfg filelist_diann.txt--` syntax to load cohort runs from a file while keeping the command length constant.

- Align DIA-NN options with FragPipe quantification, including matrix q-value, profiling, quantification, and library information flags.
- Record the staged mzML runs in `filelist_diann.txt`.

## 1.0.0

- Add cohort-wide DIA-NN quantification from an EasyPQP spectral library and one mzML per sample.
- Add Boutros Lab configuration, input validation, output records, and a skipped nf-test integration scaffold.
