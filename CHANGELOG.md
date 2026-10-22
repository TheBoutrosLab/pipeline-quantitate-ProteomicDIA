# Changelog

All notable changes to `pipeline-quantitate-ProteomicDIA` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-10-22

### Added

- Support DIA-NN `.speclib` libraries, including predicted libraries with a required source FASTA and optional reannotation ([#4](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/4)).
- Support additional DIA-NN options through a `'DIA-NN'` configuration namespace with direct snake_case-to-flag mapping.
- Add an NFTest integration case for predicted libraries.

### Changed

- Use one `params.library` setting for EasyPQP TSV and DIA-NN `.speclib` inputs.
- Write DIA-NN options and mzML paths to the generated `--cfg` file to keep the invocation short.
- Set protein inference defaults by library type and warn about inconsistent FASTA or protein inference settings during configuration.

### Fixed

- Keep process logs as individual files after successful runs ([#2](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/2)).

## [1.0.0] - 2026-10-19

### Added

- Add cohort-wide DIA-NN quantification from an EasyPQP spectral library and one mzML per sample.
- Add Boutros Lab configuration, input validation, output records, and a skipped nf-test integration scaffold.
- Align DIA-NN options with FragPipe quantification, including matrix q-value, profiling, quantification, and library information flags.
- Use FragPipe’s verified trailing `--cfg filelist_diann.txt--` syntax to load cohort runs from a file while keeping the command length constant.
- Record staged mzML runs in `filelist_diann.txt` within the work directory.
- Make DIA-NN fragment interference removal configurable, disabled by default to match FragPipe.
- Publish only dataset-prefixed DIA-NN reports, `diann.log`, and `output.sha512` directly in the DIA-NN output directory.

[1.0.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/releases/tag/v1.0.0
[1.1.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.0.0...v1.1.0
[unreleased]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.1.0...HEAD
