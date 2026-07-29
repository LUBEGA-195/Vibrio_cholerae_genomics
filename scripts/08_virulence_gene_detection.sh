#!/bin/bash
###############################################################################
# Script Name : 08_virulence_gene_detection.sh
# Author      : Bacterial Group: Nakayenga Latifah, Lubega Brian, Karogendo Vincent.
# Project     : Vibrio cholerae Genomics Pipeline
#
# Purpose:
# Screen each species-confirmed genome assembly for virulence genes using
# ABRicate against the VFDB (Virulence Factor Database), and compile the
# results into a single presence/absence matrix.
#
# Key virulence genes expected in V. cholerae:
#   ctxA, ctxB  - Cholera toxin subunits (CTX prophage)
#   tcpA        - Toxin-co-regulated pilus (TCP)
#   tcpB-tcpQ   - TCP biogenesis cluster
#   zot         - Zonula occludens toxin
#   ace         - Accessory cholera enterotoxin
#   hlyA        - El Tor haemolysin
#   mshA        - Mannose-sensitive haemagglutinin
#   vpsI/II     - Vibrio polysaccharide biosynthesis clusters
#   hapA        - Haemagglutinin/protease
###############################################################################
set -euo pipefail
###############################################################################
# Directory configuration
###############################################################################
PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"
SPECIES_DIR="$PROJECT_DIR/results/species_confirmation"
SPECIES_SUMMARY="$SPECIES_DIR/species_confirmation_summary.tsv"
VIRULENCE_DIR="$PROJECT_DIR/results/virulence"
ABRICATE_DIR="$VIRULENCE_DIR/abricate"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/virulence_gene_detection.log"
SUMMARY_FILE="$VIRULENCE_DIR/virulence_detection_summary.tsv"
MATRIX_FILE="$VIRULENCE_DIR/virulence_summary_matrix.tsv"
###############################################################################
# ABRicate configuration
# VFDB is the standard database for virulence factor screening.
# Change ABRICATE_DB to 'ecoh' or another db if needed.
###############################################################################
ABRICATE_DB="vfdb"
ABRICATE_MINID=80
ABRICATE_MINCOV=80
###############################################################################
# Key V. cholerae virulence genes to highlight in the summary
###############################################################################
KEY_GENES="ctxA ctxB tcpA zot ace hlyA mshA hapA"

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
    mkdir -p "$VIRULENCE_DIR"
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

    echo "Samples to screen for virulence genes:" | tee -a "$LOG_FILE"
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
    positive=0
    negative=0

    echo "Starting virulence gene detection with ABRicate ($ABRICATE_DB, minid=${ABRICATE_MINID}, mincov=${ABRICATE_MINCOV})..." | tee -a "$LOG_FILE"

    # Write summary header
    echo -e "sample\tvirulence_genes_detected\tgene_list\tkey_genes_present\tstatus" > "$SUMMARY_FILE"

    for sample in $samples
    do
        query="$ASSEMBLY_DIR/$sample/contigs.fasta"
        output="$ABRICATE_DIR/${sample}_virulence.tsv"

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
            echo "$sample virulence result already exists. Skipping run." | tee -a "$LOG_FILE"
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

        # Parse results: count and list detected virulence genes
        gene_count=$(tail -n +2 "$output" | wc -l | tr -d ' ')

        if [ "$gene_count" -gt 0 ]
        then
            gene_list=$(tail -n +2 "$output" | cut -f6 | sort -u | paste -sd ',' -)
            status="VIRULENCE_GENES_DETECTED"
            ((++positive))
        else
            gene_list="NONE"
            status="NO_VIRULENCE_GENES_DETECTED"
            ((++negative))
        fi

        # Identify which key V. cholerae virulence genes are present
        key_present=""
        for key_gene in $KEY_GENES
        do
            if echo "$gene_list" | grep -qi "$key_gene"
            then
                key_present="${key_present}${key_gene},"
            fi
        done
        key_present="${key_present%,}"   # trim trailing comma
        [ -z "$key_present" ] && key_present="NONE"

        echo -e "${sample}\t${gene_count}\t${gene_list}\t${key_present}\t${status}" >> "$SUMMARY_FILE"
        echo "$sample: $gene_count virulence gene(s) detected | Key genes: $key_present -> $status" | tee -a "$LOG_FILE"
    done

    echo "==============================" | tee -a "$LOG_FILE"
    echo "ABRicate virulence gene detection summary" | tee -a "$LOG_FILE"
    echo "Newly processed      : $processed" | tee -a "$LOG_FILE"
    echo "Skipped (cached)     : $skipped" | tee -a "$LOG_FILE"
    echo "Failed               : $failed" | tee -a "$LOG_FILE"
    echo "Samples with genes   : $positive" | tee -a "$LOG_FILE"
    echo "Samples without genes: $negative" | tee -a "$LOG_FILE"
    echo "Per-sample reports   : $ABRICATE_DIR" | tee -a "$LOG_FILE"
    echo "Summary table        : $SUMMARY_FILE" | tee -a "$LOG_FILE"
    echo "==============================" | tee -a "$LOG_FILE"
}

build_summary_matrix()
{
    echo "Building combined virulence gene presence/absence matrix..." | tee -a "$LOG_FILE"
    reports=("$ABRICATE_DIR"/*_virulence.tsv)

    if [ -e "${reports[0]}" ]
    then
        abricate --summary "${reports[@]}" > "$MATRIX_FILE"
        echo "Combined presence/absence matrix written: $MATRIX_FILE" | tee -a "$LOG_FILE"
    else
        echo "WARNING: No ABRicate virulence reports found. Skipping matrix generation." | tee -a "$LOG_FILE"
    fi
}

###############################################################################
# Main execution
###############################################################################
echo "============================================================" | tee -a "$LOG_FILE"
echo "Module 8: Virulence Gene Detection" | tee -a "$LOG_FILE"
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
echo "Module 8: Virulence gene detection completed successfully" | tee -a "$LOG_FILE"
echo "Finished: $(date)" | tee -a "$LOG_FILE"
echo "Results : $VIRULENCE_DIR" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"
