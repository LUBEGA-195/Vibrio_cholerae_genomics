#!/usr/bin/env bash

###############################################################################
# Script Name: 03_read_trimming.sh
#
# Purpose:
# Trim and filter paired-end FASTQ reads using fastp.
#
# Input:
# Validated raw FASTQ files from data/raw/
#
# Output:
# Clean paired-end FASTQ reads in data/clean/
# fastp reports in results/trimming/
#
# Author:
# BACTERIAL GROUP
#
###############################################################################
set -euo pipefail

###############################################################################
# Directory configuration
###############################################################################

PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")

RAW_DIR="$PROJECT_DIR/data/raw"

CLEAN_DIR="$PROJECT_DIR/data/clean"

TRIM_DIR="$PROJECT_DIR/results/trimming"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/trimming.log"

#check for presence of required dependencies

check_dependencies()
{
echo "checking for required software..."
if command -v fastp &> /dev/null 
then
   echo "fastp exists" | tee -a "$LOG_FILE"
else
   echo "ERROR fastp does not exist" | tee -a "$LOG_FILE"
   exit 1
fi
echo "All required software found" | tee -a "$LOG_FILE"


}

create_output_directories()
{
echo "creating required output directories"
mkdir -p "$CLEAN_DIR"
mkdir -p "$TRIM_DIR"
mkdir -p "$LOG_DIR"
echo "Output directories created" | tee -a "$LOG_FILE"

}

discover_samples()
{

samples=$(for fastq in "$RAW_DIR"/*.fastq
do
    basename "$fastq" | sed 's/_[12]\.fastq//'
done | sort -u)

echo "Samples detected:" | tee -a "$LOG_FILE"

for sample in $samples
do
    echo "$sample" | tee -a "$LOG_FILE"
done

}

run_fastp()
{

successful=0
failed=0

echo "Starting read trimming with fastp..." | tee -a "$LOG_FILE"

for sample in $samples
do

    echo "Processing $sample" | tee -a "$LOG_FILE"

    fastp \
    -i "$RAW_DIR/${sample}_1.fastq" \
    -I "$RAW_DIR/${sample}_2.fastq" \
    -o "$CLEAN_DIR/${sample}_R1.clean.fastq.gz" \
    -O "$CLEAN_DIR/${sample}_R2.clean.fastq.gz" \
    -h "$TRIM_DIR/${sample}.fastp.html" \
    -j "$TRIM_DIR/${sample}.fastp.json"

    if [ $? -eq 0 ]
    then
        echo "$sample trimming completed successfully" | tee -a "$LOG_FILE"
        ((successful=successful+1))
    else
        echo "ERROR: $sample trimming failed" | tee -a "$LOG_FILE"
        ((failed=failed+1))
    fi

done

echo "==============================" | tee -a "$LOG_FILE"
echo "fastp summary" | tee -a "$LOG_FILE"
echo "Successful: $successful" | tee -a "$LOG_FILE"
echo "Failed: $failed" | tee -a "$LOG_FILE"
echo "Clean reads: $CLEAN_DIR" | tee -a "$LOG_FILE"
echo "==============================" | tee -a "$LOG_FILE"

}


###############################################################################
# Main workflow
###############################################################################


check_dependencies
create_output_directories
discover_samples
run_fastp
