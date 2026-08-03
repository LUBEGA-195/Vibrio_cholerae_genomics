#!/bin/bash
###############################################################################
# Script Name : 07_amr_gene_detection.sh
# Author      : Bacterial Group: Nakayenga Latifah, Lubega Brian, Karogendo Vincent.
# Project     : Vibrio cholerae Genomics Pipeline
#
# Purpose:
# Screen each species-confirmed genome assembly for acquired antimicrobial
# resistance (AMR) genes using ABRicate against a curated AMR gene database,
# and compile the results into a single presence/absence matrix.

###############################################################################
set -euo pipefail
###############################################################################
# Directory configuration
###############################################################################
PROJECT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"
ASSEMBLY_DIR="${PROJECT_DIR}/results/assembly"
SPECIES_DIR="${PROJECT_DIR}/results/species_confirmation"
SPECIES_SUMMARY="${SPECIES_DIR}/species_confirmation_summary.tsv"
AMR_DIR="${PROJECT_DIR}/results/amr"
ABRICATE_DIR="${AMR_DIR}/abricate"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/amr_gene_detection.log"
SUMMARY_FILE="${AMR_DIR}/amr_detection_summary.tsv"
MATRIX_FILE="${AMR_DIR}/amr_summary_matrix.tsv"
###############################################################################
# ABRicate configuration
# Change ABRICATE_DB to screen against a different curated database
# (e.g. card, resfinder, argannot, megares, ecoh, plasmidfinder).
###############################################################################
ABRICATE_DB="ncbi"
ABRICATE_MINID=90
ABRICATE_MINCOV=80
check_dependencies()
{
    echo "checking required software..." | tee -a "${LOG_FILE}"
    for tool in abricate
    do
        if command -v "$tool" &> /dev/null
        then
            echo "$tool found" | tee -a "${LOG_FILE}"
        else
            echo "ERROR: $tool not found" | tee -a "${LOG_FILE}"
            exit 1
        fi
    done
    echo "All required software found" | tee -a "${LOG_FILE}"
}
create_output_directories()
{
    echo "creating required output directories" | tee -a "${LOG_FILE}"
    mkdir -p "${AMR_DIR}"
    mkdir -p "${ABRICATE_DIR}"
    mkdir -p "${LOG_DIR}"
    echo "Output directories created" | tee -a "${LOG_FILE}"
}
check_database()
{
    echo "Checking ABRicate database: ${ABRICATE_DB}..." | tee -a "${LOG_FILE}"
    if abricate --list | awk '{print $1}' | grep -qx "${ABRICATE_DB}"
    then
        echo "Database ${ABRICATE_DB} is available" | tee -a "${LOG_FILE}"
    else
        echo "ERROR: ABRicate database '${ABRICATE_DB}' not found. Run 'abricate-get_db --db $ABRICATE_DB' first." | tee -a "${LOG_FILE}"
        exit 1
    fi
}
discover_samples()
{
    echo "Discovering species-confirmed samples..." | tee -a "${LOG_FILE}"
    if [ -s "${SPECIES_SUMMARY}" ]
    then
        echo "Using ${SPECIES_SUMMARY} to restrict screening to CONFIRMED samples" | tee -a "${LOG_FILE}"
        samples=$(awk -F'\t' 'NR>1 && $5=="CONFIRMED" {print $1}' "${SPECIES_SUMMARY}")
    else
        echo "WARNING: ${SPECIES_SUMMARY} not found. Falling back to all assembled samples." | tee -a "${LOG_FILE}"
        samples=$(
            for sample in "${ASSEMBLY_DIR}"/*
            do
                if [ -f "${sample}/contigs.fasta" ]
                then
                    basename "${sample}"
                fi
            done
        )
    fi
    echo "Samples to screen for AMR genes:" | tee -a "${LOG_FILE}"
    for sample in ${samples}
    do
        echo "${sample}" | tee -a "${LOG_FILE}"
    done
}
run_abricate()
{
    processed=0
    skipped=0
    failed=0
    positive=0
    negative=0
    echo "Starting AMR gene detection with ABRicate (${ABRICATE_DB}, minid=${ABRICATE_MINID}, mincov=${ABRICATE_MINCOV})..." | tee -a "${LOG_FILE}"
    echo -e "sample\tamr_genes_detected\tgene_list\tstatus" > "${SUMMARY_FILE}"
    for sample in ${samples}
    do
        query="${ASSEMBLY_DIR}/${sample}/contigs.fasta"
        output="${ABRICATE_DIR}/${sample}_amr.tsv"
        if [ ! -f "$query" ]
        then
            echo "ERROR: contigs.fasta for ${sample} not found. Skipping." | tee -a "${LOG_FILE}"
            echo -e "${sample}\tNA\tNA\tERROR" >> "${SUMMARY_FILE}"
            ((++failed))
            continue
        fi
        if [ -f "$output" ]
        then
            echo "${sample} ABRicate result already exists. Skipping run." | tee -a "${LOG_FILE}"
            ((++skipped))
        else
            echo "Running ABRicate for ${sample} against $ABRICATE_DB..." | tee -a "${LOG_FILE}"
            if abricate --db "$ABRICATE_DB" --minid "$ABRICATE_MINID" --mincov "$ABRICATE_MINCOV" "$query" > "$output"
            then
                echo "${sample} ABRicate completed successfully" | tee -a "${LOG_FILE}"
                ((++processed))
            else
                echo "ERROR: ${sample} ABRicate run failed" | tee -a "${LOG_FILE}"
                echo -e "${sample}\tNA\tNA\tERROR" >> "${SUMMARY_FILE}"
                ((++failed))
                continue
            fi
        fi
        # Record the AMR gene calls, whether just generated or already on
        # disk, so re-running the script never drops a sample from the summary.
        gene_count=$(tail -n +2 "$output" | wc -l | tr -d ' ')
        if [ "$gene_count" -gt 0 ]
        then
            gene_list=$(tail -n +2 "$output" | cut -f6 | paste -sd ',' -)
            status="AMR_GENES_DETECTED"
            ((++positive))
        else
            gene_list="NONE"
            status="NO_AMR_GENES_DETECTED"
            ((++negative))
        fi
        echo -e "${sample}\t${gene_count}\t${gene_list}\t${status}" >> "${SUMMARY_FILE}"
        echo "${sample}: $gene_count AMR gene(s) detected -> $status" | tee -a "${LOG_FILE}"
    done
    echo "==============================" | tee -a "${LOG_FILE}"
    echo "ABRicate AMR gene detection summary" | tee -a "${LOG_FILE}"
    echo "Newly processed: $processed" | tee -a "${LOG_FILE}"
    echo "Skipped (already existed): $skipped" | tee -a "${LOG_FILE}"
    echo "Failed to run: $failed" | tee -a "${LOG_FILE}"
    echo "Samples with AMR genes detected: $positive" | tee -a "${LOG_FILE}"
    echo "Samples with no AMR genes detected: $negative" | tee -a "${LOG_FILE}"
    echo "Per-sample ABRicate reports: ${ABRICATE_DIR}" | tee -a "${LOG_FILE}"
    echo "Summary table: ${SUMMARY_FILE}" | tee -a "${LOG_FILE}"
    echo "==============================" | tee -a "${LOG_FILE}"
}
build_summary_matrix()
{
    echo "Building combined AMR gene presence/absence matrix..." | tee -a "${LOG_FILE}"
    reports=("${ABRICATE_DIR}"/*_amr.tsv)
    if [ -e "${reports[0]}" ]
    then
        abricate --summary "${reports[@]}" > "${MATRIX_FILE}"
        echo "Combined matrix written: ${MATRIX_FILE}" | tee -a "${LOG_FILE}"
    else
        echo "WARNING: No ABRicate reports found. Skipping matrix generation." | tee -a "${LOG_FILE}"
    fi
}
check_dependencies
create_output_directories
check_database
discover_samples
run_abricate
build_summary_matrix
echo "AMR gene detection completed successfully" | tee -a "${LOG_FILE}"
 
