# nf-core/pacvar: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## dev - [11/1/2026]
This is new dev version includes new features with copy number variation calling (hificnv), PacBio’s new structural variant calling (sawfish), per-CpG methylation scores (pb-CpG-tools). The template is also compliance with nf-core/tool 3.5.1.  Additional updates include new parameters and assets incorporating withe new features, updated nf-core modules, and updated local subworkflow adapting new features and topic-based nf-core modules.

### `Added`

- modules:
    - `hificnv`: Integrated the hificnv module for copy-number variant  (CNVs) calling, positioned either before or after SNVs calling depending on the skip_snp parameter.
    - `sawfish/discover` and `sawfish/jointcall`: Integrated sawfish as an optional structural variant caller, configurable via `sv_caller = ['pbsv', 'sawfish']`.
    - `pbcpgtools/alignedbamtoscore`: Integrated the pbcpgtools/alignedbamcpgscores module for CpG methylation profiling, placed before or after hiphase based on the skip_phase setting.
- main paramters (`nextlfow.config`):
    - `sv_caller`: an optional structural variant caller `['pbsv', 'sawfish]`
    - `skip_cnv` : to skip copy number variation calling by `hificnv`
    - `skip_cpg` : tp skip CpG methylation scoring    
- genome paramters (`igenome.config`):
    - `expected_cv`: BED files telling sawfish or hificnv what copy number it should see in each genomic interval. Files are provided by PacBio and stored in `assets/sawfish/`
    - `cnv_excluded_regions`: BED files specifying regions excluded from CNV calling. Files are provided by PacBio and stored in `assets/sawfish/`.
- files in `assets/sawfish/` for copy number variant calling 

### `Fixed`
- Updated nf-core template to version 3.5.1  
- Update modules (12/2025):
    - bcftools/sort
    - deepvariant/callvariants
    - deepvariant/makeexamples
    - deepvariant/postprocessvariants
    - deepvariant/rundeepvariant
    - fastqc
    - gatk4/haplotypecaller
    - gunzip
    - hiphase
    - hificnv
    - lima
    - multiqc
    - pbcpgtools/alignedbamtocpgscores
    - pbmm2/align
    - pbsv/discvoer
    - pbsv/call
    - samtools/index
    - samtools/sort
    - sawfish/discover
    - sawfish/jointcall
    - tabix/bgzip
    - trgt/genotype
    - trgt/plot
- Adopted to some topic-based modules (`trgt`, `bcftools`, and etc)

### `Dependencies`

### `Deprecated`

## v1.0.1 - Sardine [02/26/2025]

### `Added`

### `Fixed`

- [#19](https://github.com/nf-core/pacvar/pull/19) Changed files produced downstream from PBSV to have an output file name containing 'sv' to indicate origin of the files, as with those files downstream from GATK4 and Deepvariant have 'snv' in output file name (@tanyasarkjain)
- [#21](https://github.com/nf-core/pacvar/pull/21) Tweaks to the channels passed into HiPhase - specifically ensure that the inputted VCF and BAM channel are ordered in the same way (according to their shared meta). (@tanyasarkjain)

### `Dependencies`

### `Deprecated`

## v1.0.0 - Goldfish [01/31/2025]

Initial release of nf-core/pacvar, created with the [nf-core](https://nf-co.re/) template.
