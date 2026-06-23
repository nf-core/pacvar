# nf-core/pacvar: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - Kākāpō Awakens [2026-06-05]

Kākāpō Awakens expands the WGS workflow with new copy number variant, structural variant, methylation, Fiber-seq, and variant annotation capabilities. This release also updates the pipeline template to nf-core/tools 4.0.2 and refreshes core nf-core modules and infrastructure.

### Added

- [nf-core/pacvar#41](https://github.com/nf-core/pacvar/pull/41): Optional fail BAM support in the samplesheet for the repeat workflow, with HiFi and fail BAM merging (`pbbam/pbmerge`) after mapping. (@stvdsomp, reviewed by @chaochaowong)
- [nf-core/pacvar#42](https://github.com/nf-core/pacvar/pull/42): Added CNV calling with `hificnv`, optional sawfish SV calling with `sawfish/discover` and `sawfish/jointcall`, CpG methylation profiling with `pbcpgtools/alignedbamtoscore`. Added related controls and resources, including `sv_caller`, `skip_cnv`, `skip_cpg`, `expected_cv`, `cnv_excluded_regions`, and `assets/sawfish/` CNV assets. (@chaochaowong, reviewed by @vagkaratzas and @tanyasarkjain)
- [nf-core/pacvar#43](https://github.com/nf-core/pacvar/pull/43): Additional CNV testing configuration. (@chaochaowong, reviewed by @maxulysse)
- [nf-core/pacvar#48](https://github.com/nf-core/pacvar/pull/48): Ensembl Variant Effect Predictor (VEP) annotation for SNVs and small indels. (@chaochaowong, reviewed by @maxulysse)
- [nf-core/pacvar#50](https://github.com/nf-core/pacvar/pull/50): Expanded VEP annotation support for SVs and CNVs, including variant-type-specific VEP custom arguments. (@chaochaowong, reviewed by @nvnieuwk)
- [nf-core/pacvar#52](https://github.com/nf-core/pacvar/pull/52): Optional VEP cache download support. (@chaochaowong, reviewed by @pinin4fjords)
- [nf-core/pacvar#53](https://github.com/nf-core/pacvar/pull/53): Fiber-seq support with fibertools-rs modules for m6A prediction (`fibertoolsrs/predictm6a`), nucleosome positioning (`fibertoolsrs/addnucleosomes`), and m6A/nucleosome extraction (`fibertoolsrs/extract`). Adds Fiber-seq control parameters (`params.skip_fiberseq`, `params.skip_m6A_predict`), output publishing, and test profiles for kinetics-only (`conf/test_fiberseq_with_kinetics.config`) and m6A-tagged (`conf/test_fiberseq_with_m6A_tags.config`) BAMs. (@chaochaowong, reviewed by @YiJin-Xiong)
- [nf-core/pacvar#54](https://github.com/nf-core/pacvar/pull/54): Added nf-core template 4.0.2 container configuration files for conda lock files, Docker, and Singularity images across `amd64` and `arm64` architectures. (@chaochaowong, reviewed by @mashehu)
- [nf-core/pacvar#61](https://github.com/nf-core/pacvar/pull/61): (1) Removed duplicated anonymous AWS S3 client setting and fixed test profile reference configuration. (2) Updated CHANGELOG.md (@chaochaowong, reviewed by @SPPearce)

### Changed

- [nf-core/pacvar#42](https://github.com/nf-core/pacvar/pull/42): Updated 16 nf-core modules as part of the expanded WGS variant calling, methylation, and PacBio BAM processing support.
- [nf-core/pacvar#43](https://github.com/nf-core/pacvar/pull/43): Reorganized nf-test sample sheets from `assets/*.csv` into `tests/csv`.
- [nf-core/pacvar#44](https://github.com/nf-core/pacvar/pull/44): Renamed the HiFiCNV control parameter from `skip_cnv` to `skip_hificnv` to clarify that it only disables HiFiCNV, not sawfish CNV calling. Updated the workflow, schema, configuration files, documentation, and metadata to use the new parameter name.
- [nf-core/pacvar#48](https://github.com/nf-core/pacvar/pull/48): Updated `main.nf` and `workflows/pacvar.nf` to initialize VEP attributes and conditionally run SNV annotation with VEP. Updated schema, documentation, template compatibility, and test configurations for VEP annotation coverage and faster WGS test runs.
- [nf-core/pacvar#52](https://github.com/nf-core/pacvar/pull/52): Refined module output configuration for `TABIX`, `BCFTOOLS`, `pb-CpG-tools`, `HiFiCNV`, and `DEEPVARIANT_RUNDEEPVARIANT` outputs, and optimized `ENSEMBLVEP_DOWNLOAD` arguments.
- [nf-core/pacvar#53](https://github.com/nf-core/pacvar/pull/53): Updated `workflows/pacvar.nf` to run the fibertools m6A/add-nucleosomes subworkflow on phased SNV BAMs when phasing is available, otherwise on sorted BAMs.
- [nf-core/pacvar#54](https://github.com/nf-core/pacvar/pull/54): Updated the nf-core template to nf-core/tools 4.0.2 and updated MultiQC and core nf-core utility modules/subworkflows; updated `main.nf` and `workflows/pacvar.nf` to pass the new MultiQC workflow inputs after the template merge.
- [nf-core/pacvar#55](https://github.com/nf-core/pacvar/pull/55): Bumped version to 1.1.0 for release.

### Fixed

- [nf-core/pacvar#54](https://github.com/nf-core/pacvar/pull/54): Replaced remaining uppercase `Channel` factory calls with lowercase `channel` calls for newer Nextflow syntax compatibility; fixed PACVAR workflow argument syntax after the nf-core/tools template update.

### Dependencies

| Tool          | Previous version | New version |
| ------------- | ---------------- | ----------- |
| bcftools      | 1.20             | 1.22        |
| deepvariant   | 1.6              | 1.9.0       |
| ensemblvep    | -                | 115.2       |
| fibertools-rs | -                | 0.7.1       |
| gatk4         | 4.5.0            | 4.6.2       |
| gunzip        | (ubuntu:22.04)   | 1.13        |
| hiphase       | 1.4.5            | 1.5.0       |
| hificnv       | -                | 1.0.1       |
| lima          | 2.9              | 2.12        |
| multiqc       | 1.27             | 1.34        |
| pbcpgtools    | -                | 3.0.0       |
| pbmm2         | 1.14.99          | 1.14.99     |
| pbsv          | 2.9.0            | 2.11.0      |
| pbtk          | -                | 3.1.1       |
| samtools      | 1.21             | 1.22.1      |
| sawfish       | -                | 2.2.0       |
| tabix         | 1.11             | 1.21        |
| trgt          | 1.2              | 5.0.0       |

### Removed

- [nf-core/pacvar#54]: Removed legacy `.github/CONTRIBUTING.md`, `assets/adaptivecard.json`, and `assets/slackreport.json` template files.

## v1.0.1 - Sardine [02/26/2025]

### Added

### Fixed

- [#19](https://github.com/nf-core/pacvar/pull/19) Changed files produced downstream from PBSV to have an output file name containing 'sv' to indicate origin of the files, as with files downstream from GATK4 and DeepVariant having 'snv' in the output file name. (@tanyasarkjain)
- [#21](https://github.com/nf-core/pacvar/pull/21) Tweaks to the channels passed into HiPhase - specifically ensure that the input VCF and BAM channels are ordered in the same way (according to their shared meta). (@tanyasarkjain)

### Dependencies

### Deprecated

## v1.0.0 - Goldfish [01/31/2025]

Initial release of nf-core/pacvar, created with the [nf-core](https://nf-co.re/) template.
