# nf-core/pacvar: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0dev - [2026-04-16] [PR #45](https://github.com/nf-core/pacvar/pull/45)

### Added
- **Annotation Support:**
    - Integrated **Ensembl Variant Effect Predictor (VEP)** for SNV and small indel annotation.
    - New subworkflow: `subworkflows/local/vcf_annotate_vep/main.nf` to coordinate the annotation process.
    - New subworkflow: `subworkflows/local/vep_cache_initialisation/main.nf` to manage cache staging and path validation.
- **Parameters & Schema:**
    - Added `params.skip_annotation` to allow bypassing the annotation stage.
    - Added `params.vep_custom_args` to allow users to pass additional flags to VEP.
    - Added `params.vep_out_format` to toggle between VCF and Tabular output.
    - Integrated VEP-specific genome attributes (`vep_cache_version`, `vep_genome`, `vep_species`) into `conf/igenomes.config`.
- **Configuration:**
    - Created `conf/modules/ensemblvep.config` for `ensemblvep` modular process configuration.
- **Module:**
    - Added `ensemblvep/vep` and `ensemblvep/download` nf-core modules.    

### Changes
- Modified `main.nf` to initialize VEP attributes using `getGenomeAttribute` and `vep_cache_initialisation` subworkflow.
- Updated `workflows/pacvar.nf` to include conditional logic for running SNVs annotation with VEP based on `params.skip_annotation`, `params.skip_snp`, and `params.workflow`.
- Updated `nextflow_schema.json` to include all new parameters for CLI validation and documentation.
- Update documentation (`README.md`, `docs/images`, `docs/output.md`, `CITATION.md`).
- Update the pipeline to be compliant with template 3.5.2.

### Dependencies
| Tool        | Previous version | New version |
| ----------- | ---------------- | ----------- |
| ensemblvep  |                  | 115.2       |

### Deprecated

## 1.1.0dev - [2026-03-13] [PR #44](https://github.com/nf-core/pacvar/pull/44)

Renamed the parameter `skip_cnv` to `skip_hificnv` to better reflect its intended behavior. The previous name was ambiguous because the pipeline includes `sawfish`, which also performs CNV calling. Using `skip_cnv` could therefore be interpreted as disabling all CNV calling. Renaming the parameter to `skip_hificnv` clarifies that the flag controls whether the `HiFiCNV` step is executed, while sawfish’s CNV calling remains unaffected.

### Added

### Changed

- Renamed pipeline parameter `skip_cnv` → `skip_hificnv`
- README.md
- conf/test_full.config
- conf/test_wgs_deepvariant.config
- conf/test_wgs_gatk.config
- conf/test_wgs_hificnv.config
- conf/test_wgs_sawfish.config
- docs/usage.md
- nextflow.config
- nextflow_schema.json
- ro-crate-metadata.json
- workflows/pacvar.nf

## 1.1.0dev - [2026-03-10] [PR #43](https://github.com/nf-core/pacvar/pull/43)

Addressed the reviewers's comments on [PR #42](https://github.com/nf-core/pacvar/pull/42) by improving testing for copy number variant (CNV) calling and reorganizing files in the `assets` directory.

### Added

- Moved all sample sheets used by `tests/*.nf.test` from `assets/*.csv` to the `tests/csv` directory to improve organization.
  - `tests/csv/samplesheet_karyotype.csv`
  - `tests/csv/samplesheet_pbmerge.csv`
  - `tests/csv/samplesheet_repeat_id.csv`
- Added a configuration file for CNV calling using `HiFiCNV` and `sawfish`
  - `conf/test_wgs_hificnv.config`

### Changed

Updated `nextflow.config` to include the newly-added configuration file

### Removed

- `assets/amplesheet_karyotype.csv`
- `assets/samplesheet_pbmerge.csv`
- `assets/samplesheet_repeat_id.csv`

## 1.1.0dev - [1/20/2026] [PR #42](https://github.com/nf-core/pacvar/pull/42)

This is new dev version includes new features with copy number variation calling (hificnv), PacBio’s new structural variant calling (sawfish), per-CpG methylation scores (pb-CpG-tools), and PacBio merge bam (pbtk/pbmerge). The template is also compliance with nf-core/tool 3.5.1. Additional updates include new parameters and assets incorporating withe new features, updated nf-core modules, and updated local subworkflow adapting new features and topic-based nf-core modules.

### Added

- modules:
  - `hificnv`: Integrated the hificnv module for copy-number variant (CNVs) calling, positioned either before or after SNVs calling depending on the skip_snp parameter.
  - `sawfish/discover` and `sawfish/jointcall`: Integrated sawfish as an optional structural variant caller, configurable via `sv_caller = ['pbsv', 'sawfish']`.
  - `pbcpgtools/alignedbamtoscore`: Integrated the pbcpgtools/alignedbamcpgscores module for CpG methylation profiling, placed before or after hiphase based on the skip_phase setting.
  - `pbbam/pbmerge`: Integrated the pbbam/pbmerge module to merge multiple PacBio BAM files into a single BAM file using the PacBio BAM (pbbam) library.
- main paramters (`nextlfow.config`):
  - `sv_caller`: an optional structural variant caller `['pbsv', 'sawfish]`
  - `skip_cnv` : to skip copy number variation calling by `hificnv`
  - `skip_cpg` : tp skip CpG methylation scoring
- genome paramters (`igenome.config`):
  - `expected_cv`: BED files telling sawfish or hificnv what copy number it should see in each genomic interval. Files are provided by PacBio and stored in `assets/sawfish/`
  - `cnv_excluded_regions`: BED files specifying regions excluded from CNV calling. Files are provided by PacBio and stored in `assets/sawfish/`.
- files in `assets/sawfish/` for copy number variant calling

### Fixed

- [#35](https://github.com/nf-core/pacvar/pull/37) Important! Template update for nf-core/tools v3.5.1
- [#31](https://github.com/nf-core/pacvar/issues/31) Update deepvariant
- [#30](https://github.com/nf-core/pacvar/issues/30) Replace pbsv with sawfish; `sawfish` added but not replacing `pbsv`

### Dependencies

| Tool        | Previous version | New version |
| ----------- | ---------------- | ----------- |
| bcftools    | 1.20             | 1.22        |
| deepvariant | 1.6              | 1.9.0       |
| gatk4       | 4.5.0            | 4.6.2       |
| gunzip      | (ubuntu:22.04)   | 1.13        |
| hiphase     | 1.4.5            | 1.5.0       |
| hificnv     | -                | 1.0.1       |
| lima        | 2.9              | 2.12        |
| multiqc     | 1.27             | 1.33        |
| pbcpgtools  | -                | 3.0.0       |
| pbmm2       | 1.14.99          | 1.14.99     |
| pbsv        | 2.9.0            | 2.11.0      |
| pbtk        | -                | 3.1.1       |
| samtools    | 1.21             | 1.22.1      |
| sawfish     | -                | 2.2.0       |
| tabix       | 1.11             | 1.21        |
| trgt        | 1.2              | 5.0.0       |

### Deprecated

## v1.0.1 - Sardine [02/26/2025]

### Added

### Fixed

- [#19](https://github.com/nf-core/pacvar/pull/19) Changed files produced downstream from PBSV to have an output file name containing 'sv' to indicate origin of the files, as with those files downstream from GATK4 and Deepvariant have 'snv' in output file name (@tanyasarkjain)
- [#21](https://github.com/nf-core/pacvar/pull/21) Tweaks to the channels passed into HiPhase - specifically ensure that the inputted VCF and BAM channel are ordered in the same way (according to their shared meta). (@tanyasarkjain)

### Dependencies

### Deprecated

## v1.0.0 - Goldfish [01/31/2025]

Initial release of nf-core/pacvar, created with the [nf-core](https://nf-co.re/) template.
