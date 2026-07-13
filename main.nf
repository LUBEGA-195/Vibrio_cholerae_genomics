nextflow.enable.dsl = 2

process FASTQC {

    tag "${sample}"

    publishDir "results/fastqc", mode: 'copy'

    conda "bioconda::fastqc"

    input:
    tuple val(sample), path(reads)

    output:
    path "*_fastqc.html"
    path "*_fastqc.zip"

    script:
    """
    fastqc ${reads}
    """
}

workflow {

    Channel
        .fromFilePairs("data/fastq/*_{1,2}.fastq")
        | FASTQC
}
