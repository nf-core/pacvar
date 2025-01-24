# nf-core/pacvar: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [LIMA](#lima) - Demultiplex samples
- [PBMM2](#pbmm2) - Align samples to reference genome
- [SAMTOOLS SORT](#samtools-sort) - Sort BAM files
- [SAMTOOLS INDEX](#samtools-sort) - Index BAM files
- [DEEPVARIANT](#deepvariant-rundeepvariant) - Variant call SNVs
- [HAPLOTYPECALLER](#gatk4-haplotypecaller) - Variant call SNVs
- [pbsv](#pbsv) - Variant call SVs
- [TRGT](#trgt) - Genotype and Plot structural variants
- [BCFTOOLS](#bcftools-index) - Index VCF files
- [HIPHASE](#Hiphase) - Phase VCF, and BAM files
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

When `--skip_demultiplexing` is false (default behavior)

### LIMA

<details markdown="1">
<summary>Output files</summary>

- `lima/`
  - `<sample><barcode-pair>.bam`: The demultiplexed bamfiles
  - `<basename>.bam.pbi`: The Pacbio index of bam files
  - `<sample>.lima.counts`: Counts of the number of reads found for each demultiplexed sample
  - `<sample>.lima.report`: Tab-separated file about each ZMW (Zero-Mode Waveguide), unfiltered
  - `<sample>.lima.summary`: File that shows how many ZMWs (Zero-Mode Waveguide) have been filtered, how ZMWs many are same/different

</details>

[LIMA](https://lima.how) demultiplex samples

Note:

- If `--skip_demultiplexing` is true:
  `<basename> = <sample>`
- If `--skip_demultiplexing` is false:
  `<basename> = <sample>.<barcode-pair>`

### PBMM2

<details markdown="1">
<summary>Output files</summary>

- `pbmm2/`
  - `<basename>.aligned.bam`: Aligned BAM

</details>

[PBMM2](https://github.com/PacificBiosciences/pbmm2) Aligned BAM files

### SAMTOOLS

<details markdown="1">
<summary>Output files</summary>

- `samtools/`
  - `<basename>.sorted.bam`: The sorted BAM file.
  - `<basename>.sorted.bam.bai`: The indexed BAM file.

</details>

[SAMTOOLS](https://github.com/samtools/samtools) Sort and index aligned bams.

### GATK4

<details markdown="1">
<summary>Output files</summary>

- `gatk4/`
  - `<basename>.vcf.gz`: VCF of the SNV
  - `<basename>.vcf.gz.tbi`: Associated indexes for the VCF files

</details>

[GATK4](https://github.com/broadinstitute/gatk/tree/master/src/main/java/org/broadinstitute/hellbender/tools/walkers/haplotypecaller) HaplotypeCaller - SNV detection and Variant Call tool.

### PBSV

<details markdown="1">
<summary>Output files</summary>

- `pbsv/`
  - `<basename>.pbsv.vcf`: VCF of SV
  - `<basename>.svsig.gz`: File containing signatures of structural variants

</details>

[PBSV](https://github.com/PacificBiosciences/pbsv). Discover and call structural variants

### HIPHASE

<details markdown="1">
<summary>Output files</summary>

- `hiphase/`
  - `<basename>.phased.bam`: Haplotagged BAM
  - `<basename>.phased.vcf`: The phased Variant File
  - `<basename>.phased.vcf`: This CSV/TSV file contains information about the the phase blocks that were output by HiPhase.

</details>

[`HIPHASE`](https://github.com/PacificBiosciences/HiPhase/tree/main)

### TABIX

<details markdown="1">
<summary>Output files</summary>

- `tabix/`
  - `<basename>.vcf.gz`: Zipped PBSV VCF files

</details>

[TABIX](https://github.com/samtools/htslib) VCF file handler - VCF zipping.

### BCFTOOLS

<details markdown="1">
<summary>Output files</summary>

- `BCFTOOLS/`
  - `<basename>.vcf.gz.csi`: Index of PBSV VCF files

</details>

[BCFTOOLS](https://github.com/samtools/bcftools) Manipulates VCF files including Indexes them

### DEEPVARIANT

<details markdown="1">
<summary>Output files</summary>

- `deepvariant/`
  - `<basename>.vcf.gz`: Zipped VCF file
  - `<basename>.vcf.gz.tbi`: Associated index to zipped VCF file

</details>

[DEEPVARIANT](https://github.com/google/deepvariant) SNV caller

### TRGT

<details markdown="1">
<summary>Output files</summary>

- `trgt/`
  - `<basename>.bam.vcf.gz`: VCF file for the repeat region
  - `<basename>.bam.spanning.bam`: BAM for the repeat region
  - `<basename>.png`: Waterfall plot of the repeat region

Example png output: sample1_C9ORF72.png
![example: sample1_C9ORF72.png](images/sample1_C9ORF72.png)

</details>

[TRGT](https://github.com/PacificBiosciences/trgt) Plots and Genotypes tandem repeats

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
