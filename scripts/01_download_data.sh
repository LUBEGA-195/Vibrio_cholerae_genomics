#!/bin/bash

###############################################################################
# Script Name : 01_download_data.sh
# Author      : Bacterial Group
# Project     : Vibrio cholerae Genomics Pipeline
# Description : Downloads paired-end FASTQ files from NCBI SRA.
###############################################################################

set -eou pipefail

PROJECT_DIR="$HOME/vibrio_cholerae_genomics"

CONFIG_DIR="$PROJECT_DIR/config"

RAW_DIR="$PROJECT_DIR/data/raw"

LOG_DIR="$PROJECT_DIR/logs"

SAMPLESHEET="$CONFIG_DIR/samples.csv"

LOG_FILE="$LOG_DIR/download.log"

###############################################################################
# Create required directories
###############################################################################

mkdir -p "$RAW_DIR"
mkdir -p "$LOG_DIR"

check_dependencies()
{ echo "checking required software..."

for tool in prefetch fasterq-dump
do

	if command -v "$tool" &> /dev/null
then
    echo "$tool found" | tee -a "$LOG_FILE"
else
    echo "ERROR: $tool not found" | tee -a "$LOG_FILE"
    exit 1
fi
done
	echo "All required tools available" | tee -a "$LOG_FILE"

}

check_inputs()
{
	echo "Checking input files..." | tee -a "$LOG_FILE"

	if [ ! -f "$SAMPLESHEET" ]
	then
	echo "ERROR: Sample sheet not found: $SAMPLESHEET" | tee -a "$LOG_FILE"
	exit 1
	else
	echo "Sample sheet found." | tee -a "$LOG_FILE"
	fi
}

validate_samplesheet()
{
    echo "Validating sample sheet..." | tee -a "$LOG_FILE"

    if [ ! -f "$SAMPLESHEET" ]
    then
        echo "ERROR: Sample sheet not found: $SAMPLESHEET" | tee -a "$LOG_FILE"
        exit 1
    fi


    if ! head -n 1 "$SAMPLESHEET" | grep -q "accession"
    then
        echo "ERROR: Sample sheet missing accession column" | tee -a "$LOG_FILE"
        exit 1
    fi


    missing_accessions=$(awk -F',' 'NR>1 && $2=="" {print $1}' "$SAMPLESHEET")


    if [ -n "$missing_accessions" ]
    then
        echo "ERROR: Missing accession values for:" | tee -a "$LOG_FILE"
        echo "$missing_accessions" | tee -a "$LOG_FILE"
        exit 1
    fi


    echo "Sample sheet validation successful." | tee -a "$LOG_FILE"
}

download_sra()
{
    echo "Starting SRA downloads..." | tee -a "$LOG_FILE"

    successful=0
    failed=0

    for accession in $(awk -F',' 'NR>1 {print $2}' "$SAMPLESHEET")
    do
        echo "Processing $accession..." | tee -a "$LOG_FILE"

        # Check if FASTQ already exists
        if [ -s "$RAW_DIR/${accession}_1.fastq" ] && [ -s "$RAW_DIR/${accession}_2.fastq" ]
        then
   echo "$accession FASTQ already exists. Skipping." | tee -a "$LOG_FILE"
        successful=$((successful + 1))
        continue
        fi


        # Download SRA file
        if prefetch "$accession" --output-directory "$RAW_DIR"
        then
            echo "$accession download completed." | tee -a "$LOG_FILE"
        else
            echo "ERROR: $accession download failed." | tee -a "$LOG_FILE"
            failed=$((failed + 1))
            continue
        fi

	#Safety check for complete accession.sra download
    if [ -f "$RAW_DIR/$accession/$accession.sra" ]
    then
    	echo "$accession SRA download complete" | tee -a "$LOG_FILE"
    else
    	echo "ERROR: $accession SRA download incomplete" | tee -a "$LOG_FILE"
	rm -rf "$RAW_DIR/$accession"
    	failed=$((failed + 1))
    	continue
    fi


        # Convert SRA to FASTQ
        if fasterq-dump "$RAW_DIR/$accession" \
            --split-files \
            --outdir "$RAW_DIR"
        then
            echo "$accession converted successfully." | tee -a "$LOG_FILE"
            
        else
            echo "ERROR: $accession FASTQ conversion failed." | tee -a "$LOG_FILE"
            failed=$((failed + 1))
        fi

	if [ -s "$RAW_DIR/${accession}_1.fastq" ] && [ -s "$RAW_DIR/${accession}_2.fastq" ]
	then
    	echo "$accession FASTQ validation passed." | tee -a "$LOG_FILE"
    	successful=$((successful + 1))
	else
    	   echo "ERROR: $accession FASTQ validation failed." | tee -a "$LOG_FILE"
    	   failed=$((failed + 1))
	fi

    done


    # FINAL SUMMARY GOES HERE
    echo "===============================" | tee -a "$LOG_FILE"
    echo "SRA download summary" | tee -a "$LOG_FILE"
    echo "Successful samples: $successful" | tee -a "$LOG_FILE"
    echo "Failed samples: $failed" | tee -a "$LOG_FILE"
    echo "FASTQ location: $RAW_DIR" | tee -a "$LOG_FILE"
    echo "===============================" | tee -a "$LOG_FILE"

}


###############################################################################
# Main workflow
###############################################################################
check_dependencies
check_inputs
validate_samplesheet
download_sra
