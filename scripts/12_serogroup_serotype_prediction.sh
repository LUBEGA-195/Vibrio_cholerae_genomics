#!/usr/bin/env bash

###############################################################################
# Module 12: Serogroup / Serotype Prediction
###############################################################################

set -euo pipefail

ASSEMBLY_DIR="results/assembly"
DB="reference/serogroup_db/serogroup_markers"
OUTPUT_DIR="results/serogroup_serotype"
LOG_DIR="logs"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/module12_serogroup.log"

echo "===================================================" | tee "$LOG_FILE"
echo "Module 12: Serogroup / Serotype Prediction" | tee -a "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"
echo "===================================================" | tee -a "$LOG_FILE"

##########################################################################
# Check dependencies
##########################################################################

for tool in blastn grep awk basename dirname
do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: $tool not installed." | tee -a "$LOG_FILE"
        exit 1
    }
done

##########################################################################
# Check directories
##########################################################################

if [ ! -d "$ASSEMBLY_DIR" ]; then
    echo "ERROR: Assembly directory not found." | tee -a "$LOG_FILE"
    exit 1
fi

##########################################################################
# Output summary
##########################################################################

echo -e "Sample\tSerogroup\tSerotype" \
> "$OUTPUT_DIR/serotype_summary.tsv"

##########################################################################
# Analyse each genome
##########################################################################

for assembly in "$ASSEMBLY_DIR"/*/contigs.fasta
do

    sample=$(basename "$(dirname "$assembly")")

    echo "Processing $sample..." | tee -a "$LOG_FILE"

    blastn \
        -query "$assembly" \
        -db "$DB" \
        -evalue 1e-20 \
        -perc_identity 90 \
        -outfmt "6 sseqid pident length bitscore" \
        > "$OUTPUT_DIR/${sample}.blast"

    serogroup="Unknown"
    serotype="Unknown"

    ############################################################
    # O1
    ############################################################

    if grep -q "^rfbV" "$OUTPUT_DIR/${sample}.blast"
    then

        serogroup="O1"

        if grep -q "^wbeT" "$OUTPUT_DIR/${sample}.blast"
        then
            serotype="Ogawa"
        else
            serotype="Inaba"
        fi

    ############################################################
    # O139
    ############################################################

    elif grep -q "^wbfZ" "$OUTPUT_DIR/${sample}.blast"
    then

        serogroup="O139"
        serotype="NA"

    ############################################################
    # Other
    ############################################################

    else

        serogroup="non-O1/non-O139"
        serotype="NA"

    fi

    echo -e "${sample}\t${serogroup}\t${serotype}" \
    >> "$OUTPUT_DIR/serotype_summary.tsv"

done

echo "Finished: $(date)" | tee -a "$LOG_FILE"

echo "Results saved in $OUTPUT_DIR" | tee -a "$LOG_FILE"
