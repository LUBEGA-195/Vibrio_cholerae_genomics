#!/bin/bash
###############################################################################
# Script Name : 08_snp_analysis.sh
# Author      : Bacterial Group: Nakayenga Latifah, Lubega Brian, Karogendo Vincent.
# Project     : Vibrio cholerae Genomics Pipeline
#
# Purpose:
# Reference-based SNP calling and pairwise comparison across all isolates,
# using Snippy (per-isolate variant calling), snippy-core (combining calls
# into a shared core-genome SNP alignment), and snp-dists (pairwise SNP
# distance matrix) - the direct "how many SNPs apart are sample A and B"
# comparison that this module is meant to produce.

###############################################################################
set -euo pipefail
###############################################################################
# Directory configuration
###############################################################################
PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
CLEAN_DIR="$PROJECT_DIR/data/clean"
REFERENCE_DIR="$PROJECT_DIR/data/reference"
SNP_DIR="$PROJECT_DIR/results/snp_analysis"
SNIPPY_DIR="$SNP_DIR/snippy"
CORE_DIR="$SNP_DIR/core"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/snp_analysis.log"
###############################################################################
# Reference genome configuration
# Same reference as 06_species_confirmation.sh - kept identical on purpose
# so species confirmation and SNP calling agree with each other.
# Vibrio cholerae O1 biovar El Tor str. N16961 (Heidelberg et al. 2000)
###############################################################################
REFERENCE_ACCESSION="GCF_000006745.1"
REFERENCE_ASSEMBLY="ASM674v1"
REFERENCE_BASENAME="${REFERENCE_ACCESSION}_${REFERENCE_ASSEMBLY}"
REFERENCE_GENOME="$REFERENCE_DIR/${REFERENCE_BASENAME}_genomic.fna"
REFERENCE_URL="https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/006/745/${REFERENCE_BASENAME}/${REFERENCE_BASENAME}_genomic.fna.gz"
###############################################################################
# Run configuration
###############################################################################
THREADS=12
CORE_PREFIX="core"
check_dependencies()
{
    echo "checking required software..." | tee -a "$LOG_FILE"
    for tool in snippy snippy-core snp-dists
    do
        if command -v "$tool" &> /dev/null
        then
            echo "$tool found" | tee -a "$LOG_FILE"
        else
            echo "ERROR: $tool not found" | tee -a "$LOG_FILE"
            exit 1
        fi
    done
    echo "All required software found" | tee -a "$LOG_FILE"
}
create_output_directories()
{
    echo "creating required output directories" | tee -a "$LOG_FILE"
    mkdir -p "$SNIPPY_DIR"
    mkdir -p "$CORE_DIR"
    mkdir -p "$REFERENCE_DIR"
    mkdir -p "$LOG_DIR"
    echo "Output directories created" | tee -a "$LOG_FILE"
}
check_reference()
{
    echo "Checking reference genome..." | tee -a "$LOG_FILE"
    if [ -s "$REFERENCE_GENOME" ]
    then
        echo "Reference genome found: $REFERENCE_GENOME" | tee -a "$LOG_FILE"
    else
        echo "Reference genome not found. Downloading $REFERENCE_ACCESSION ($REFERENCE_ASSEMBLY)..." | tee -a "$LOG_FILE"
        if curl -sfL -o "${REFERENCE_GENOME}.gz" "$REFERENCE_URL"
        then
            gunzip -f "${REFERENCE_GENOME}.gz"
            echo "Reference genome downloaded successfully" | tee -a "$LOG_FILE"
        else
            echo "ERROR: Failed to download reference genome from $REFERENCE_URL" | tee -a "$LOG_FILE"
            exit 1
        fi
    fi
    if [ ! -s "$REFERENCE_GENOME" ]
    then
        echo "ERROR: Reference genome missing or empty: $REFERENCE_GENOME" | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Reference genome ready: $REFERENCE_GENOME" | tee -a "$LOG_FILE"
}
discover_samples()
{
    echo "Discovering trimmed read samples..." | tee -a "$LOG_FILE"
    samples=$(
        for fastq in "$CLEAN_DIR"/*_R1.clean.fastq.gz
        do
            basename "$fastq" | sed 's/_R1\.clean\.fastq\.gz//'
        done | sort -u
    )
    echo "Samples detected:" | tee -a "$LOG_FILE"
    for sample in $samples
    do
        if [ -f "$CLEAN_DIR/${sample}_R1.clean.fastq.gz" ] && [ -f "$CLEAN_DIR/${sample}_R2.clean.fastq.gz" ]
        then
            echo "$sample" | tee -a "$LOG_FILE"
        else
            echo "ERROR: $sample missing paired clean read file" | tee -a "$LOG_FILE"
        fi
    done
}
run_snippy()
{
    processed=0
    skipped=0
    failed=0
    echo "Starting per-isolate SNP calling with Snippy (reference: $REFERENCE_ACCESSION)..." | tee -a "$LOG_FILE"
    for sample in $samples
    do
        r1="$CLEAN_DIR/${sample}_R1.clean.fastq.gz"
        r2="$CLEAN_DIR/${sample}_R2.clean.fastq.gz"
        outdir="$SNIPPY_DIR/$sample"

        if [ -f "$outdir/snps.vcf" ]
        then
            echo "$sample Snippy result already exists. Skipping run." | tee -a "$LOG_FILE"
            ((++skipped))
            continue
        fi

        # Snippy refuses to write into a pre-existing --outdir, so clear
        # out any partial directory left behind by an earlier failed run
        rm -rf "$outdir"

        echo "Running Snippy for $sample..." | tee -a "$LOG_FILE"
        if snippy --cpus "$THREADS" --outdir "$outdir" --ref "$REFERENCE_GENOME" --R1 "$r1" --R2 "$r2"
        then
            echo "$sample Snippy completed successfully" | tee -a "$LOG_FILE"
            ((++processed))
        else
            echo "ERROR: $sample Snippy run failed" | tee -a "$LOG_FILE"
            ((++failed))
        fi
    done
    echo "==============================" | tee -a "$LOG_FILE"
    echo "Snippy per-isolate SNP calling summary" | tee -a "$LOG_FILE"
    echo "Successful: $processed" | tee -a "$LOG_FILE"
    echo "Skipped: $skipped" | tee -a "$LOG_FILE"
    echo "Failed: $failed" | tee -a "$LOG_FILE"
    echo "Per-sample results: $SNIPPY_DIR" | tee -a "$LOG_FILE"
    echo "==============================" | tee -a "$LOG_FILE"
}
run_snippy_core()
{
    echo "Combining per-isolate results into a core SNP alignment..." | tee -a "$LOG_FILE"

    snippy_dirs=""
    for sample in $samples
    do
        if [ -f "$SNIPPY_DIR/$sample/snps.vcf" ]
        then
            snippy_dirs="$snippy_dirs $SNIPPY_DIR/$sample"
        else
            echo "WARNING: $sample has no completed Snippy output, excluding from core alignment" | tee -a "$LOG_FILE"
        fi
    done

    if [ -z "$snippy_dirs" ]
    then
        echo "ERROR: No completed Snippy results available to build a core alignment" | tee -a "$LOG_FILE"
        exit 1
    fi

    cd "$CORE_DIR"
    # snippy_dirs is intentionally unquoted below to word-split into
    # separate positional arguments for snippy-core
    # shellcheck disable=SC2086
    if snippy-core --ref "$REFERENCE_GENOME" --prefix "$CORE_PREFIX" $snippy_dirs
    then
        echo "snippy-core completed successfully" | tee -a "$LOG_FILE"
    else
        echo "ERROR: snippy-core failed" | tee -a "$LOG_FILE"
        exit 1
    fi
    cd - > /dev/null

    echo "Core SNP alignment: $CORE_DIR/${CORE_PREFIX}.aln" | tee -a "$LOG_FILE"
    echo "Whole-genome alignment: $CORE_DIR/${CORE_PREFIX}.full.aln" | tee -a "$LOG_FILE"
    echo "Per-sample alignment stats: $CORE_DIR/${CORE_PREFIX}.txt" | tee -a "$LOG_FILE"
}
run_snp_dists()
{
    echo "Computing pairwise SNP distance matrix..." | tee -a "$LOG_FILE"
    core_aln="$CORE_DIR/${CORE_PREFIX}.aln"
    distance_matrix="$CORE_DIR/snp_distance_matrix.tsv"

    if [ ! -s "$core_aln" ]
    then
        echo "ERROR: Core alignment not found: $core_aln" | tee -a "$LOG_FILE"
        exit 1
    fi

    if snp-dists "$core_aln" > "$distance_matrix"
    then
        echo "Pairwise SNP distance matrix written successfully" | tee -a "$LOG_FILE"
        echo "Distance matrix: $distance_matrix" | tee -a "$LOG_FILE"
    else
        echo "ERROR: snp-dists failed" | tee -a "$LOG_FILE"
        exit 1
    fi
}
check_dependencies
create_output_directories
check_reference
discover_samples
run_snippy
run_snippy_core
run_snp_dists
echo "SNP-based comparative analysis completed successfully" | tee -a "$LOG_FILE"
