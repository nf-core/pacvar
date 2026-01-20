<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-pacvar_logo_dark.png">
    <img alt="nf-core/pacvar" src="docs/images/nf-core-pacvar_logo_light.png">
  </picture>
</h1>

[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/nf-core/pacvar)
[![GitHub Actions CI Status](https://github.com/nf-core/pacvar/actions/workflows/nf-test.yml/badge.svg)](https://github.com/nf-core/pacvar/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/nf-core/rnaseq/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-core/rnaseq/actions/workflows/linting.yml)[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/rnaseq/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.1400710-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.1400710)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.2-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.5.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.5.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/nf-core/pacvar)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23pacvar-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/pacvar)[![Follow on Bluesky](https://img.shields.io/badge/bluesky-%40nf__core-1185fe?labelColor=000000&logo=bluesky)](https://bsky.app/profile/nf-co.re)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**nf-core/pacvar** is a bioinformatics pipeline that processes long-read PacBio data. Specifically, the pipeline provides two workflows: one for processing whole-genome sequencing data, and another for processing reads from the PureTarget expansion panel offered by PacBio. This second workflow characterizes tandem repeats. Because the pipeline is designed for PacBio reads, it uses PacBio’s officially released tools.

![nf-core/pacvar metro map](docs/images/pacvar_white_background.png)

Workflow Overview

1. Demultiplex reads ([`lima`](https://lima.how))
2. Align reads ([`pbmm2`](https://github.com/PacificBiosciences/pbmm2))
3. Sort and index alignments ([`SAMtools`](https://sourceforge.net/projects/samtools/files/samtools/))

WGS Workflow Overview

1. Choice of SNVs and small indels calling routes:
   a. [`deepvariant`](https://github.com/google/deepvariant)
   b. [`HaplotypeCaller`](https://gatk.broadinstitute.org/hc/en-us/articles/360037225632-HaplotypeCaller)
2. Choice of SV calling routes:
   a. [`pbsv`](https://github.com/PacificBiosciences/pbsv)
   b. [`sawfish`](https://github.com/PacificBiosciences/sawfish)
3. Index VCF files ([`bcftools`](https://samtools.github.io/bcftools/bcftools.html))
4. Phase SNVs, SVs and BAM files ([`hiphase`](https://github.com/PacificBiosciences/HiPhase))
5. Call CNVs ([`hificnv`](https://github.com/PacificBiosciences/HiFiCNV))
6. Extracts per-CpG methylation scores ([`pb-CpG-tools::aligned_bam_to_cpg_scores`](https://github.com/PacificBiosciences/pb-CpG-tools))

Tandem Repeat Workflow Overview

1. Genotype tandem repeats - produce spanning bams and vcf ([`TRGT`](https://github.com/PacificBiosciences/trgt))
2. Index and Sort tandem tepeat spanning bam ([`SAMtools`](https://sourceforge.net/projects/samtools/files/samtools/))
3. Plot repeat motif plots ([`TRGT`](https://github.com/PacificBiosciences/trgt))
4. Sort spanning VCF ([`bcftools`](https://samtools.github.io/bcftools/bcftools.html))

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,bam,pbi
CONTROL,AEG588A1_S1_L002_R1_001.bam,AEG588A1_S1_L002_R1_001.pbi
```

Note that the `.pbi` file is not required. If you choose not to include it, your input file might look like this:

```csv
sample,bam,pbi
CONTROL,AEG588A1_S1_L002_R1_001.bam
```

Each row represents an unaligned bam file and their associated index (optional).

Now, you can run the pipeline. Below is an example

```bash
nextflow run nf-core/pacvar \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   --workflow <wgs/repeat> \
   --barcodes barcodes.bed \
   --intervals intervals.bed \
   --genome <GENOME NAME (e.g. GATK.GRCh38)> \
   --outdir <OUTDIR>
```

optional paramaters include: `--skip_demultiplexing`, `--skip_snp`, `--skip_sv`, `--skip_phase`, `--skip_cnv`, and `--skip_cpg`.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [usage documentation](https://nf-co.re/pacvar/usage) and the [parameter documentation](https://nf-co.re/pacvar/parameters).

## Pipeline output

To see the results of an example test run with a full size dataset refer to the [results](https://nf-co.re/pacvar/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://nf-co.re/pacvar/output).

## Credits

nf-core/pacvar was originally written by Tanya Sarkin Jain.

We thank the following people for their extensive assistance in the development of this pipeline:

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#pacvar` channel](https://nfcore.slack.com/channels/pacvar) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

If you use nf-core/pacvar for your analysis, please cite it using the following doi: [10.5281/zenodo.14813048](https://doi.org/10.5281/zenodo.14813048) and publication:

> Tanya Jain, Claire Clelland, nf-core/pacvar: a pipeline for analyzing longread PacBio whole genome and repeat expansion sequencing data, Bioinformatics, 2025;, btaf116, https://doi.org/10.1093/bioinformatics/btaf116

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
