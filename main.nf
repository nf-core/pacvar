#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/pacvar
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/pacvar
    Website: https://nf-co.re/pacvar
    Slack  : https://nfcore.slack.com/channels/pacvar
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PACVAR                   } from './workflows/pacvar/'
include { ENSEMBLVEP_DOWNLOAD      } from './modules/nf-core/ensemblvep/download/main'
include { UTILS_ANNOTATION_CACHE   } from './subworkflows/nf-core/utils_annotation_cache/main'
include { PIPELINE_INITIALISATION  } from './subworkflows/local/utils_nfcore_pacvar_pipeline'
include { PIPELINE_COMPLETION      } from './subworkflows/local/utils_nfcore_pacvar_pipeline'
include { getGenomeAttribute	   } from './subworkflows/local/utils_nfcore_pacvar_pipeline'

params.fasta                = getGenomeAttribute('fasta')
params.fasta_fai            = getGenomeAttribute('fasta_fai')
params.dbsnp                = getGenomeAttribute('dbsnp')
params.dbsnp_tbi            = getGenomeAttribute('dbsnp_tbi')
params.dict                 = getGenomeAttribute('dict')
params.expected_cn          = getGenomeAttribute('expected_cn')
params.cnv_excluded_regions = getGenomeAttribute('cnv_excluded_regions')
params.vep_cache_version    = getGenomeAttribute('vep_cache_version')
params.vep_genome           = getGenomeAttribute('vep_genome')
params.vep_species          = getGenomeAttribute('vep_species')


//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_PACVAR {

    take:
    samplesheet             // channel: samplesheet read in from --input
    fasta                   // channel: [mandatory] fasta
    fasta_fai               // channel: [mandatory] fasta_fai
    dict                    // channel: [mandatory] dict
    dbsnp                   // channel: [mandatory] dbsnp
    dbsnp_tbi               // channel: [mandatory] dbsnp_tbi
    intervals               // channel: [mandatory] intervals
    expected_cn             // channel: [mandatory] expected_cn
    cnv_excluded_regions    // channel: [mandatory] cnv_excluded_regions

    main:


    // vep cache initialization
    // 1. Define ensemblvep_enable based on params.workflow and params.skip_ensemblvep
    def ensemblvep_enabled = (params.workflow == 'wgs') ? !params.skip_ensemblvep : false
    vep_cache = []

    // 2. Download vep_cache
    if (params.download_vep_cache && ensemblvep_enabled) {
        // Prepare input for the download module: [ [id], genome, species, version ]
        ch_ensemblvep_info = channel.of([
            [ id:"${params.vep_cache_version}_${params.vep_genome}" ],
            params.vep_genome,
            params.vep_species,
            params.vep_cache_version
        ])

        // Execute Download
        ENSEMBLVEP_DOWNLOAD(ch_ensemblvep_info, true)
        vep_cache = ENSEMBLVEP_DOWNLOAD.out.cache.first() // [meta, cache] and convert it to value channel
    }
    else if (ensemblvep_enabled) {
        // staging vep cache
        UTILS_ANNOTATION_CACHE (
            params.vep_cache,           // ensemblvep_cache
            params.vep_cache_version,   // ensemblvep_cache_version
            params.vep_custom_args_snv, // ensemblvep_custom_args_snv (only checking args contain --merge or --refseq)
            params.vep_genome,          // ensemblvep_genome
            params.vep_species,         // ensemblvep_species
            ensemblvep_enabled,         // ensemblvep_enabled
            [],                         // snpeff_cache
            [],                         // snpeff_db
            false,                      // snpeff_enabled
            []                          // help_message
        )
        vep_cache = UTILS_ANNOTATION_CACHE.out.ensemblvep_cache // [meta, cache]  or [] depending on ensemblvep_enable
    }

    //
    // WORKFLOW: Run pipeline
    //
    PACVAR (
        samplesheet,
        fasta,
        fasta_fai,
        dict,
        dbsnp,
        dbsnp_tbi,
        intervals,
        expected_cn,
        cnv_excluded_regions,
        vep_cache,
        params.vep_cache_version,
        params.vep_genome,
        params.vep_species
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.outdir,
    )

    emit:
    multiqc_report = PACVAR.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow {
    main:

    // Initialize genomic attibutes with associated meta data maps as channels
    fasta                = params.fasta ? channel.fromPath(params.fasta).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.empty()
    fasta_fai            = params.fasta_fai ? channel.fromPath(params.fasta_fai).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.empty()
    dict                 = params.dict ? channel.fromPath(params.dict).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.empty()
    dbsnp                = params.dbsnp ? channel.fromPath(params.dbsnp).collect() : channel.value([])
    dbsnp_tbi            = params.dbsnp_tbi ? channel.fromPath(params.dbsnp_tbi).collect() : channel.value([])
    intervals            = params.intervals ? channel.fromPath(params.intervals).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.value([[],[]])

    expected_cn          = params.expected_cn ? channel.fromPath(params.expected_cn).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.value([[:], []])
    cnv_excluded_regions = params.cnv_excluded_regions ? channel.fromPath(params.cnv_excluded_regions).map{ it -> [ [id:it.baseName], it ] }.collect() : channel.value([[:], []])

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PACVAR (
        PIPELINE_INITIALISATION.out.samplesheet,
        fasta,
        fasta_fai,
        dict,
        dbsnp,
        dbsnp_tbi,
        intervals,
        expected_cn,
        cnv_excluded_regions
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_PACVAR.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
