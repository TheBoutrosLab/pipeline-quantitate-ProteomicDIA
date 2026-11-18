# Changelog

All notable changes to `pipeline-quantitate-ProteomicDIA` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.1] - 2026-11-18

### Fixed

- Use staged acquisition filenames in the DIA-NN file list to avoid crashes with long absolute paths ([#17](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/17)).
- Cap an inherited unlimited soft stack limit at 8 MiB before launching DIA-NN while preserving finite limits ([#18](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/18)).

## [1.3.0] - 2026-11-11

### Added

- Quantify fractionated DIA cohorts with fraction-specific EasyPQP libraries and publish only combined report, precursor, peptide, and protein-group quantities across fractions ([#13](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/13)).
- Publish the sample-to-acquisition table and fraction-specific DIA-NN logs with the final results.

### Changed

- Use upstream R lintr with project-specific four-space indentation while retaining the existing Python and YAML static checks.
- Preserve native DIA-NN reports for unfractionated cohorts and run cross-fraction R aggregation only when fractions are present.

## [1.2.0] - 2026-11-03

### Added

- Add optional copy staging of acquisitions and reference inputs into the task work directory, enabled in the HeLa dia-PASEF integration case.
- Add a HeLa dia-PASEF DIA-NN integration case using the original `.d` acquisition and its generated EasyPQP library.
- Accept original Bruker `.d` acquisition directories alongside mzML files and publish the sample-to-acquisition manifest ([#8](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/8)).

### Fixed

- Preserve and validate fragment type, series number, charge, and neutral loss from EasyPQP annotations in a staged DIA-NN TSV library ([#9](https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/issues/9)).

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
[1.2.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.1.0...v1.2.0
[1.3.0]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.2.0...v1.3.0
[1.3.1]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.3.0...v1.3.1
[unreleased]: https://github.com/TheBoutrosLab/pipeline-quantitate-ProteomicDIA/compare/v1.3.1...HEAD
