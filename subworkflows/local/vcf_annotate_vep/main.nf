//
// SNV ANNOTATION with VEP
//

include { ENSEMBLVEP_VEP                                } from '../../../modules/nf-core/ensemblvep/vep'
// include { ENSEMBLVEP_VEP as VCF_ANNOTATE_MERGE          } from '../../../modules/nf-core/ensemblvep/vep'

workflow VCF_ANNOTATE_VEP {
    take:
    vcf                        // channel: [ val(meta), vcf ]
    fasta
    vep_genome
    vep_species
    vep_cache_version
    vep_cache

    main:
    vcf_ann  = channel.empty()
    tab_ann  = channel.empty()
    json_ann = channel.empty()

    vcf_for_vep = vcf.map { meta, vcf_ -> [meta, vcf_, []] }
    ENSEMBLVEP_VEP(vcf_for_vep, vep_genome, vep_species, vep_cache_version, vep_cache, fasta, [])

    vcf_ann = vcf_ann.mix(ENSEMBLVEP_VEP.out.vcf.join(ENSEMBLVEP_VEP.out.tbi, failOnDuplicate: true, failOnMismatch: true))
    tab_ann = tab_ann.mix(ENSEMBLVEP_VEP.out.tab)
    json_ann = json_ann.mix(ENSEMBLVEP_VEP.out.json)


    emit:
    vcf_ann  // channel: [ val(meta), vcf.gz, vcf.gz.tbi ]
    tab_ann
    json_ann
}