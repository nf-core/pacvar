# nf-core/pacvar: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - Goldfish [01/31/2025]

Initial release of nf-core/pacvar, created with the [nf-core](https://nf-co.re/) template.

## v1.0.1 - Sardine [01/31/2025]

### `Added`

### `Fixed`

- Changed files produced downstream from PBSV to have an output file name containing 'pbsv' to indicate origin of the files
- Tweaks to the channels passed into HiPhase - specifically ensure that the inputted VCF and BAM channel are ordered in the same way (according to their shared meta).

### `Dependencies`

### `Deprecated`
