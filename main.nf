nextflow.enable.dsl = 2

process FASTQC {

    tag "$reads.simpleName"

    publishDir "results/fastqc", mode: 'copy'

    conda "bioconda::fastqc"

    input:
    path reads

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
        .fromPath("data/fastq/*_1.fastq")
        | FASTQC

}
