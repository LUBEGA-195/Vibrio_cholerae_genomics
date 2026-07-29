#!/bin/bash
###############################################################################
# Script Name : 09_plasmid_detection.sh
# Author      : Bacterial Group: Nakayenga Latifah, Lubega Brian, Karogendo Vincent.
# Project     : Vibrio cholerae Genomics Pipeline
#
# Purpose:
# Screen each species-confirmed genome assembly for plasmid replicon sequences
# using ABRicate against the PlasmidFinder database, and compile the results
# into a single presence/absence matrix.
#
# Background:
# Plasmids in Vibrio cholerae can carry:
#   - AMR genes (e.g., resistance integrons on IncC plasmids)
#   - Virulence accessory elements
#   - Mobile genetic elements
# Identifying replicon types helps characterise plasmid epidemiology and
# transmission of resistance across isolates.
#
# Tool   : ABRicate (https://github.com/tseemann/abricate)
# Database: PlasmidFinder (Carattoli et al. 2014)
###############################################################################
set -euo pipefail

###############################################################################
# Directory configuration
###############################################################################
PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"
SPECIES_DIR="$PROJECT_DIR/results/species_confirmation"
SPECIES_SUMMARY="$SPECIES_DIR/species_confirmation_summary.tsv"
PLASMID_DIR="$PROJECT_DIR/results/plasmid"
ABRICATE_DIR="$PLASMID_DIR/abricate"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/plasmid_detection.log"
SUMMARY_FILE="$PLASMID_DIR/plasmid_detection_summary.tsv"
MATRIX_FILE="$PLASMID_DIR/plasmid_summary_matrix.tsv"

###############################################################################
# ABRicate / PlasmidFinder configuration
# PlasmidFinder identifies replicon sequences and reports their incompatibility
# group (Inc type), which determines plasmid compatibility and mobility.
# Lower minid/mincov than AMR/virulence is standard for replicon detection.
###############################################################################
ABRICATE_DB="plasmidfinder"
ABRICATE_MINID=80
ABRICATE_MINCOV=60

check_dependencies()
{
    echo "Checking required software..." | tee -a "$LOG_FILE"
    for tool in abricate
    do
        if command -v "$tool" &> /dev/null
        then
            echo "$tool found" | tee -a "$LOG_FILE"
        else
            echo "ERROR: $tool not found. Install ABRicate before running this script." | tee -a "$LOG_FILE"
            exit 1
        fi
    done
    echo "All required software found" | tee -a "$LOG_FILE"
}

create_output_directories()
{
    echo "Creating required output directories..." | tee -a "$LOG_FILE"
    mkdir -p "$PLASMID_DIR"
    mkdir -p "$ABRICATE_DIR"
    mkdir -p "$LOG_DIR"
    echo "Output directories created" | tee -a "$LOG_FILE"
}

check_database()
{
    echo "Checking ABRicate database: $ABRICATE_DB..." | tee -a "$LOG_FILE"
    if abricate --list | awk '{print $1}' | grep -qx "$ABRICATE_DB"
    then
        echo "Database '$ABRICATE_DB' is available" | tee -a "$LOG_FILE"
    else
        echo "ERROR: ABRicate database '$ABRICATE_DB' not found." | tee -a "$LOG_FILE"
        echo "Run: abricate-get_db --db $ABRICATE_DB --force" | tee -a "$LOG_FILE"
        exit 1
    fi
}

discover_samples()
{
    echo "Discovering species-confirmed samples..." | tee -a "$LOG_FILE"
    if [ -s "$SPECIES_SUMMARY" ]
    then
        echo "Using $SPECIES_SUMMARY to restrict screening to CONFIRMED samples" | tee -a "$LOG_FILE"
        samples=$(awk -F'\t' 'NR>1 && $5=="CONFIRMED" {print $1}' "$SPECIES_SUMMARY")
    else
        echo "WARNING: $SPECIES_SUMMARY not found. Falling back to all assembled samples." | tee -a "$LOG_FILE"
        samples=$(
            for sample in "$ASSEMBLY_DIR"/*
            do
                if [ -f "$sample/contigs.fasta" ]
                then
                    basename "$sample"
                fi
            done
        )
    fi

    if [ -z "$samples" ]
    then
        echo "ERROR: No samples found to process. Check assembly directory: $ASSEMBLY_DIR" | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Samples to screen for plasmids:" | tee -a "$LOG_FILE"
    for sample in $samples
    do
        echo "  $sample" | tee -a "$LOG_FILE"
    done
}

run_abricate()
{
    processed=0
    skipped=0
    failed=0
    plasmid_positive=0
    plasmid_negative=0

    echo "Starting plasmid detection with ABRicate ($ABRICATE_DB, minid=${ABRICATE_MINID}, mincov=${ABRICATE_MINCOV})..." | tee -a "$LOG_FILE"

    # Write summary header
    echo -e "sample\tplasmid_replicons_detected\treplicon_list\tinc_groups\tstatus" > "$SUMMARY_FILE"

    for sample in $samples
    do
        query="$ASSEMBLY_DIR/$sample/contigs.fasta"
        output="$ABRICATE_DIR/${sample}_plasmid.tsv"

        # Verify the assembly exists
        if [ ! -f "$query" ]
        then
            echo "ERROR: contigs.fasta for $sample not found. Skipping." | tee -a "$LOG_FILE"
            echo -e "${sample}\tNA\tNA\tNA\tERROR" >> "$SUMMARY_FILE"
            ((++failed))
            continue
        fi

        # Run ABRicate (skip if output already exists)
        if [ -f "$output" ]
        then
            echo "$sample plasmid result already exists. Skipping run." | tee -a "$LOG_FILE"
            ((++skipped))
        else
            echo "Running ABRicate on $sample against $ABRICATE_DB..." | tee -a "$LOG_FILE"
            if abricate \
                --db "$ABRICATE_DB" \
                --minid "$ABRICATE_MINID" \
                --mincov "$ABRICATE_MINCOV" \
                "$query" > "$output"
            then
                echo "$sample ABRicate completed successfully" | tee -a "$LOG_FILE"
                ((++processed))
            else
                echo "ERROR: $sample ABRicate run failed" | tee -a "$LOG_FILE"
                echo -e "${sample}\tNA\tNA\tNA\tERROR" >> "$SUMMARY_FILE"
                ((++failed))
                continue
            fi
        fi

        # Parse results: count replicons and list Inc groups
        replicon_count=$(tail -n +2 "$output" | wc -l | tr -d ' ')

        if [ "$replicon_count" -gt 0 ]
        then
            # Column 6 = GENE (replicon name), e.g. IncC, IncF, ColE1
            replicon_list=$(tail -n +2 "$output" | cut -f6 | sort -u | paste -sd ',' -)

            # Extract Inc group prefix (e.g. IncC from IncC_1__IncC)
            inc_groups=$(tail -n +2 "$output" | cut -f6 | grep -oP 'Inc[A-Za-z0-9]+' | sort -u | paste -sd ',' - || echo "UNKNOWN")

            status="PLASMID_REPLICON_DETECTED"
            ((++plasmid_positive))
        else
            replicon_list="NONE"
            inc_groups="NONE"
            status="NO_PLASMID_DETECTED"
            ((++plasmid_negative))
        fi

        echo -e "${sample}\t${replicon_count}\t${replicon_list}\t${inc_groups}\t${status}" >> "$SUMMARY_FILE"
        echo "$sample: $replicon_count replicon(s) detected | Inc groups: $inc_groups -> $status" | tee -a "$LOG_FILE"
    done

    echo "==============================" | tee -a "$LOG_FILE"
    echo "ABRicate plasmid detection summary" | tee -a "$LOG_FILE"
    echo "Newly processed        : $processed" | tee -a "$LOG_FILE"
    echo "Skipped (cached)       : $skipped" | tee -a "$LOG_FILE"
    echo "Failed                 : $failed" | tee -a "$LOG_FILE"
    echo "Samples with plasmids  : $plasmid_positive" | tee -a "$LOG_FILE"
    echo "Samples without plasmid: $plasmid_negative" | tee -a "$LOG_FILE"
    echo "Per-sample reports     : $ABRICATE_DIR" | tee -a "$LOG_FILE"
    echo "Summary table          : $SUMMARY_FILE" | tee -a "$LOG_FILE"
    echo "==============================" | tee -a "$LOG_FILE"
}

build_summary_matrix()
{
    echo "Building combined plasmid replicon presence/absence matrix..." | tee -a "$LOG_FILE"
    reports=("$ABRICATE_DIR"/*_plasmid.tsv)

    if [ -e "${reports[0]}" ]
    then
        abricate --summary "${reports[@]}" > "$MATRIX_FILE"
        echo "Combined presence/absence matrix written: $MATRIX_FILE" | tee -a "$LOG_FILE"
    else
        echo "WARNING: No ABRicate plasmid reports found. Skipping matrix generation." | tee -a "$LOG_FILE"
    fi
}

###############################################################################
# Main execution
###############################################################################
echo "============================================================" | tee -a "$LOG_FILE"
echo "Module 9: Plasmid Detection" | tee -a "$LOG_FILE"
echo "Started : $(date)" | tee -a "$LOG_FILE"
echo "Database: $ABRICATE_DB | Min ID: ${ABRICATE_MINID}% | Min Cov: ${ABRICATE_MINCOV}%" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

check_dependencies
create_output_directories
check_database
discover_samples
run_abricate
build_summary_matrix

echo "============================================================" | tee -a "$LOG_FILE"
echo "Module 9: Plasmid detection completed successfully" | tee -a "$LOG_FILE"
echo "Finished: $(date)" | tee -a "$LOG_FILE"
echo "Results : $PLASMID_DIR" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
