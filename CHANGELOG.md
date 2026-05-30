# nf-core/pacvar: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.0 - [2026-05-30]

This release expands the WGS workflow with CNV, SV, 5mC methylation, Fiber-seq (m6A methylation), and VEP annotation capabilities, and updates the pipeline template to nf-core/tools 4.0.2. Detailed development entries for this release are listed in the `1.1.0dev` sections below.

### Added

- Added HiFiCNV for copy number variant calling. (@chaochaowong)
- Added sawfish for structural variant calling. (@chaochaowong)
- Added pb-CpG-tools for per-CpG methylation scoring. (@chaochaowong)
- Added pbtk/pbmerge for merging PacBio fail BAM files. (@stvdsomp)
- Added Ensembl VEP annotation for SNV, SV, and CNV outputs, including optional VEP cache download support. (@chaochaowong)
- Added fibertools-rs for Fiber-seq m6A and nucleosome processing. (@chaochaowong)

### Changed

- Updated the nf-core template to 4.0.2 and refreshed associated CI, linting, documentation, RO-Crate metadata, and container configuration files. (@chaochaowong)
- Updated workflow wiring, output publication, schema entries, documentation, and test profiles for the new variant calling, annotation, methylation, and Fiber-seq features. (@chaochaowong)

### Dependencies

- Updated core tool versions and added new dependencies including `ensemblvep`, `fibertools-rs`, `hificnv`, `pbcpgtools`, `pbtk`, and `sawfish`. Details are listed in the `1.1.0dev` sections below. (@chaochaowong)

### Fixed

- Fixed workflow argument syntax and channel factory usage for newer Nextflow syntax compatibility. (@chaochaowong)
- Fixed output naming and publication logic for several downstream variant calling and annotation outputs. (@chaochaowong)

## 1.1.0dev - [2026-05-25] template-4.0.2

### Added

- Added nf-core template 4.0.2 container configuration files for conda lock files, Docker, and Singularity images across `amd64` and `arm64` architectures.

### Changed

- Updated the pipeline template files to nf-core/tools 4.0.2, including GitHub Actions, nf-test configuration, linting/pre-commit settings, RO-Crate metadata, and documentation boilerplate.
- Updated nf-core `fastqc`, `multiqc`, `utils_nfcore_pipeline`, and `utils_nfschema_plugin` module/subworkflow files and snapshots.
- Updated `main.nf` and `workflows/pacvar.nf` to pass the new MultiQC workflow inputs after the template merge.

### Dependencies

| Tool    | Previous version | New version |
| ------- | ---------------- | ----------- |
| multiqc | 1.33             | 1.34        |

### Fixed

- Fixed PACVAR workflow argument syntax after the template merge.
- Replaced remaining uppercase `Channel` factory calls with lowercase `channel` calls for newer Nextflow syntax compatibility.

### Removed

- Removed legacy `.github/CONTRIBUTING.md`, `assets/adaptivecard.json`, and `assets/slackreport.json` template files.

## 1.1.0dev - [2026-05-20] [PR #53 add-fibertools](https://github.com/nf-core/pacvar/pull/53)

### Added

- Added the `fibertoolsrs/addnucleosomes` nf-core module to annotate Fiber-seq BAM files with nucleosome and MSP positions. (@chaochaowong, reviewed by @YiJin-Xiong)
- Added the `fibertoolsrs/predictm6a` nf-core module to predict m6A calls and add Fiber-seq nucleosome annotations. (@chaochaowong, reviewed by @YiJin-Xiong)
- Added the `fibertoolsrs/extract` nf-core module to extract m6A and nucleosome positions from Fiber-seq BAM files. (@chaochaowong, reviewed by @YiJin-Xiong)
- Added the `BAM_M6A_ADDNUCLEOSOMES_FIBERTOOLS` local subworkflow to optionally run `fibertools-rs predict-m6a` or `fibertools-rs add-nucleosomes`, index the resulting BAM files with `samtools index`, and extract m6A and nucleosome positions.
- Added `params.skip_fiberseq` to control Fiber-seq m6A and nucleosome position in the WGS workflow.
- Added `params.skip_m6A_predict` to control fibertools-rs m6A prediction.
- Added `conf/modules/fibertools.config` to publish fibertools outputs to `${params.outdir}/fibertools`.
- Added `conf/test_fiberseq_with_kinetics.config` and `conf/test_fiberseq_with_m6A_tags.config` test profiles for Fiber-seq BAMs with kinetics-only input and pre-existing m6A tags.

### Changed

- Updated `workflows/pacvar.nf` to run the fibertools m6A/add-nucleosomes subworkflow on phased SNV BAMs when phasing is available, otherwise on sorted BAMs.
- Updated `nextflow_schema.json` and `docs/output.md` to document the new Fiber-seq parameters and fibertools outputs.

### Dependencies

| Tool          | Previous version | New version |
| ------------- | ---------------- | ----------- |
| fibertools-rs | -                | 0.7.1       |

## 1.1.0dev - [2026-04-28] [PR #52 add-vep-to-sv](https://github.com/nf-core/pacvar/pull/52)

### Added

- Added `download_vep_cache` and `outdir_vep_cache` parameters to enable VEP cache downloading.
- Integrated `ENSEMBL_DOWNLOAD` module to download VEP cache.
- Added VEP custom parameters for three variant types: `vep_custom_args_sv`, `vep_custom_args_cnv`, and `vep_custom_args_snv`, and remove `vep_custom_args`. (@chaochaowong, reviewed by @pinin4fjords)
- Added VEP annotation support for Structural Variants (SV) and Copy Number Variants (CNV). (@chaochaowong, reviewed by @pinin4fjords)
- Added updated metro map, `docs/images/metro_update_v1.1.0dev_PR52.png`

### Changed

- Refactored `modules.config` to improve output directory structure for `TABIX` and `BCFTOOLS` modules.
- Updated `modules.config` to ensure output file names for `pb-CpG-tools` and `HiFiCNV` correctly reflect the input BAM file name (using `meta.file_name`).
- Updated `modules.config`to ensure the `DEEPVARIANT_RUNDEEPVARIANT` module ouput file use the suffix .snv for better variant-type clarity.
- Optimized `conf/modules/ensemblvep.config` to include specific `ext.args` for the `ENSEMBLVEP_DOWNLOAD` module.
- Updated `pacvar.nf` to integrate VEP annotation workflows for SVs and CNVs.
- Updated `docs/output.md` to document VEP cache handling and annotation outputs.
- Updated VEP custom args defaul values.
- Updated `CHANGELOG.md`
- Updated `conf/test_wgs_hificnv.config` to test the logistics of vep annotation
- Updated `conf/test_wgs_ensemblvep` to test downloading vep cache
- Updated `nextflow_schema.json` for new parameters

### Dependencies

### Deprecated

## 1.1.0dev - [2026-04-16] [PR #48 add-annotation](https://github.com/nf-core/pacvar/pull/48)

### Added

- **Annotation Support:**
  - Integrated **Ensembl Variant Effect Predictor (VEP)** for SNV and small indel annotation. (@chaochaowong, reviewed by @maxulysse)
  - Added nf-core subworkflow: `subworkflows/nf-core/vcf_annotate_ensemblvep` to coordinate the ensemblvep process.
  - Added nf-core subworkflow: `subworkflows/nf-core/utils_annotation_cache` to initialize vep cache validation.
- **Parameters & Schema:**
  - Added `params.skip_ensemblvep` to allow bypassing the annotation stage.
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
- Updated documentation (`README.md`, `docs/images`, `docs/output.md`, `CITATION.md`).
- Updated the pipeline to be compliant with template 3.5.2.
- Updated `test_full.config` to include VEP testing (`skip_annotation=false` as default)
- Update `test_wgs*.config` to set `skip_annotation = true` to save time from vep cache (~ 23G) staging

### Dependencies

| Tool       | Previous version | New version |
| ---------- | ---------------- | ----------- |
| ensemblvep |                  | 115.2       |

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

This is new dev version includes new features with copy number variation calling (hificnv), PacBio’s new structural variant calling (sawfish), per-CpG methylation scores (pb-CpG-tools), and PacBio merge bam (pbtk/pbmerge). The template is also compliance with nf-core/tool 3.5.1. Additional updates include new parameters and assets incorporating withe new features, updated nf-core modules, and updated local subworkflow adapting new features and topic-based nf-core modules. (@chaochaowong, reviewed by @tanyasarkjain and @vagkaratzas)

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
