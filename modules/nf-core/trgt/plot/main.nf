process TRGT_PLOT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/trgt:1.2.0--h9ee0642_0':
        'biocontainers/trgt:1.2.0--h9ee0642_0' }"

    input:
    tuple val(meta) , path(bam), path(bai), path(vcf), path(tbi), val(repeat_id)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)
    tuple val(meta4), path(repeats)

    output:
    tuple val(meta), path("*.{png,pdf,svg}"), emit: plot
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    if [ -z "${repeat_id}" ]; then
        mapfile -t repeat_ids < <(awk -F '\\t' '{ split(\$4,a,";"); gsub("ID=","",a[1]); print a[1] }' "${repeats}")

    else
        IFS=',; ' read -r -a repeat_ids <<< "${repeat_id}"
    fi

    for rid in "\${repeat_ids[@]}"; do

        out_png_motifs="${meta.id}_\${rid}_motifs.png"
        out_png_meth="${meta.id}_\${rid}_meth.png"

        trgt plot \\
            $args \\
            --genome ${fasta} \\
            --repeats ${repeats} \\
            --spanning-reads ${bam} \\
            --vcf ${vcf} \\
            --repeat-id "\${rid}" \\
            --show motifs \\
            --image \$out_png_motifs

        trgt plot \\
            $args \\
            --genome ${fasta} \\
            --repeats ${repeats} \\
            --spanning-reads ${bam} \\
            --vcf ${vcf} \\
            --repeat-id "\${rid}" \\
            --show meth \\
            --image \$out_png_meth
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trgt: \$(trgt --version |& sed '1!d ; s/trgt //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        trgt: \$(trgt --version |& sed '1!d ; s/trgt //')
    END_VERSIONS
    """
}
