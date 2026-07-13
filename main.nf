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

process FASTP {

    tag "${sample}"

    publishDir "results/fastp", mode: 'copy'

    conda "bioconda::fastp"

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("*_clean_R1.fastq"), path("*_clean_R2.fastq"), emit: clean_reads
    path "*_fastp.html", emit: fastp_html
    path "*_fastp.json", emit: fastp_json

    script:
    """
    fastp \
    -i ${reads[0]} \
    -I ${reads[1]} \
    -o ${sample}_clean_R1.fastq \
    -O ${sample}_clean_R2.fastq \
    -h ${sample}_fastp.html \
    -j ${sample}_fastp.json
    """
}

workflow {

    reads_ch = Channel
        .fromFilePairs("data/fastq/*_{1,2}.fastq")

    FASTQC(reads_ch)

    FASTP(reads_ch)

    FASTP.out.clean_reads.view()

}
