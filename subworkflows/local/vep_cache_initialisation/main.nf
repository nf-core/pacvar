//
// VEP CACHE INITIALISATION
//

// Initialise channels based on params or indices that were just built
// For all modules here:
// A when clause condition is defined in the conf/modules.config to determine if the module should be run
// Condition is based on params.step and params.tools
// If and extra condition exists, it's specified in comments

workflow VEP_CACHE_INITIALISATION {
    take:
    vep_cache
    vep_species
    vep_cache_version
    vep_genome
    vep_custom_args

    main:

    def vep_annotation_cache_key = isCloudUrl(vep_cache) ? "${vep_cache_version}_${vep_genome}/" : ""
    def vep_species_suffix = vep_custom_args.contains("--merged") ? '_merged' : (vep_custom_args.contains("--refseq") ? '_refseq' : '')
    def vep_cache_dir = "${vep_annotation_cache_key}${vep_species}${vep_species_suffix}/${vep_cache_version}_${vep_genome}"
    def vep_cache_path_full = file("${vep_cache}/${vep_cache_dir}", type: 'dir')
    
    if (!vep_cache_path_full.exists() || !vep_cache_path_full.isDirectory()) {
        if (vep_cache == "s3://annotation-cache/vep_cache/") {
            error("This path, ${vep_cache_path_full}, is not available within annotation-cache.\nPlease check https://annotation-cache.github.io/ to create a request for it.")
        }
        else {
            error("Path provided with VEP cache is invalid.\nMake sure there is a directory named ${vep_cache_dir} in ${vep_cache}.")
        }
    }

    // ensemblvep_cache = channel.fromPath(file("${vep_cache}/${vep_annotation_cache_key}"), checkIfExists: true).collect()
    ensemblvep_cache = channel
        .fromPath(file("${vep_cache}/${vep_annotation_cache_key}"), checkIfExists: true)
        .first()
        .map { [[id: "${vep_cache_version}_${vep_genome}"], it] }

    emit:
    ensemblvep_cache // channel: [ meta, cache ]
}

// Helper function to check if cache path is from any cloud provider
def isCloudUrl(cache_url) {
    return cache_url.startsWith("s3://") || cache_url.startsWith("gs://") || cache_url.startsWith("az://")
}
