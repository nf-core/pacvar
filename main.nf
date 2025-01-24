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
include { PACVAR                  } from './workflows/pacvar/'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_pacvar_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_pacvar_pipeline'
include { getGenomeAttribute	  } from './subworkflows/local/utils_nfcore_pacvar_pipeline'

params.fasta        = getGenomeAttribute('fasta')
params.fasta_fai    = getGenomeAttribute('fasta_fai')
params.dbsnp        = getGenomeAttribute('dbsnp')
params.dbsnp_tbi    = getGenomeAttribute('dbsnp_tbi')
params.dict         = getGenomeAttribute('dict')

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_PACVAR {

    take:
    samplesheet // channel: samplesheet read in from --input
    fasta       // channel: [mandatory] fasta
    fasta_fai   // channel: [mandatory] fasta_fai
    dict        // channel: [mandatory] dict
    dbsnp       // channel: [mandatory] dbsnp
    dbsnp_tbi   // channel: [mandatory] dbsnp_tbi
    intervals   // channel: [mandatory] intervals
    repeat_id   // channel: [mandatory] id
    karyotype   // channel: [mandatory] karyotype

    main:
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
        repeat_id,
        karyotype
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
    fasta               = params.fasta ? Channel.fromPath(params.fasta).map{ it -> [ [id:it.baseName], it ] }.collect() : Channel.empty()
    fasta_fai           = params.fasta_fai ? Channel.fromPath(params.fasta_fai).map{ it -> [ [id:it.baseName], it ] }.collect() : Channel.empty()
    dict                = params.dict ? Channel.fromPath(params.dict).map{ it -> [ [id:it.baseName], it ] }.collect() : Channel.empty()
    dbsnp               = params.dbsnp ? Channel.fromPath(params.dbsnp).collect() : Channel.value([])
    dbsnp_tbi           = params.dbsnp_tbi ? Channel.fromPath(params.dbsnp_tbi).collect() : Channel.value([])

    intervals           = params.intervals ? Channel.fromPath(params.intervals).map{ it -> [ [id:it.baseName], it ] }.collect() : Channel.value([[],[]])
    repeat_id           = params.repeat_id ? Channel.fromPath(params.repeat_id).map{ it -> [ [id:it.baseName], it.baseName ] }.collect() : Channel.value([])
    karyotype           = params.karyotype ? Channel.fromPath(params.karyotype).map{ it -> [ [id:it.baseName], it.baseName ] }.collect() : Channel.value([])

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
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
        repeat_id,
        karyotype
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
