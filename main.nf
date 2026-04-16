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
include { VEP_CACHE_INITIALISATION } from './subworkflows/local/vep_cache_initialisation'
include { ENSEMBLVEP_DOWNLOAD      } from './modules/nf-core/ensemblvep/download/main'
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

    // Initialize with default/fallback value
    vep_cache = params.vep_cache    
    
    // cache initialization if skip_annotation=false and workflow == 'wgs'
    if (!params.skip_annotation && params.workflow == 'wgs') {
        // Logic for using existing local or cloud cache
        VEP_CACHE_INITIALISATION (
            params.vep_cache,
            params.vep_species,
            params.vep_cache_version,
            params.vep_genome,
            params.vep_custom_args
        )

        vep_cache = VEP_CACHE_INITIALISATION.out.ensemblvep_cache // [meta, cache]
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
        params.hook_url,
        NFCORE_PACVAR.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
