#!/usr/bin/env bash

###############################################################################
# Script Name: 02_quality_control.sh
#
# Purpose:
# Perform quality assessment of raw FASTQ sequencing reads using FastQC
# and summarize results using MultiQC.
#
# Input:
# Raw FASTQ files located in data/raw/
#
# Output:
# FastQC reports and MultiQC summary report
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

QC_DIR="$PROJECT_DIR/results/qc"

FASTQC_DIR="$QC_DIR/fastqc"

MULTIQC_DIR="$QC_DIR/multiqc"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/qc.log"

check_dependencies()
{
echo "Checking available software" | tee -a "$LOG_FILE"

for tool in fastqc multiqc
do

    if command -v "$tool" &> /dev/null
    then
        echo "$tool found" | tee -a "$LOG_FILE"

    else
        echo "ERROR: $tool not found" | tee -a "$LOG_FILE"
        exit 1
    fi

done

echo "All required tools found" | tee -a "$LOG_FILE"
}

#Check for non- empty raw data file
# Check FASTQ files exist and are not empty
check_inputs()
{
    error_counter=0
    fastq_found=false

    # Check raw data directory
    if [ -d "$RAW_DIR" ]
    then
        echo "Raw data directory exists" | tee -a "$LOG_FILE"
    else
        ((error_counter++))
        echo "ERROR: $RAW_DIR directory does not exist" | tee -a "$LOG_FILE"
    fi


    # Check FASTQ files
    for fastq_file in "$RAW_DIR"/*.fastq
    do
        if [ -s "$fastq_file" ]
        then
            echo "$fastq_file is valid" | tee -a "$LOG_FILE"
            fastq_found=true
        else
            echo "ERROR: $fastq_file is empty" | tee -a "$LOG_FILE"
            ((error_counter+=1))
        fi
    done


#check for presence two paired-end reads.
samples=$(for fastq in "$RAW_DIR"/*.fastq
do
    basename "$fastq" | sed 's/_[12]\.fastq//'
done | sort -u)

for sample in $samples
do
    if [ -f "$RAW_DIR/${sample}_1.fastq" ] && [ -f "$RAW_DIR/${sample}_2.fastq" ]
    then
        echo "$sample paired reads found"
    else
        echo "ERROR: $sample missing paired read"
        ((error_counter +=1))
    fi
done


if [ "$error_counter" -gt 0 ]
then
    echo "Input validation failed with $error_counter errors" | tee -a "$LOG_FILE"
    exit 1
else
    echo "Input validation successful" | tee -a "$LOG_FILE"
fi

}

create_output_directories()
{
    mkdir -p "$FASTQC_DIR"
    mkdir -p "$MULTIQC_DIR"
    mkdir -p "$LOG_DIR"

    echo "Output directories created successfully." | tee -a "$LOG_FILE"
}

run_fastqc()
{
    successful=0
    failed=0
    skipped=0

    echo "Starting FastQC analysis..." | tee -a "$LOG_FILE"

    for fastq in "$RAW_DIR"/*.fastq
    do
        filename=$(basename "$fastq")
        report="${filename%.fastq}_fastqc.html"

        if [ -f "$FASTQC_DIR/$report" ]
        then
            echo "$filename FastQC report already exists. Skipping." | tee -a "$LOG_FILE"
            ((skipped+=1))

        else

            if fastqc -o "$FASTQC_DIR" "$fastq"
            then
                echo "$filename FastQC completed successfully" | tee -a "$LOG_FILE"
                ((successful+=1))

            else
                echo "ERROR: $filename FastQC failed" | tee -a "$LOG_FILE"
                ((failed+=1))

            fi

        fi


    done

echo "===============================" | tee -a "$LOG_FILE"
echo "FastQC analysis summary" | tee -a "$LOG_FILE"
echo "Successful: $successful" | tee -a "$LOG_FILE"
echo "Skipped: $skipped" | tee -a "$LOG_FILE"
echo "Failed: $failed" | tee -a "$LOG_FILE"
echo "FASTQC reports: $FASTQC_DIR" | tee -a "$LOG_FILE"
echo "===============================" | tee -a "$LOG_FILE"

}

run_multiqc()
{
echo "Starting MultiQC analysis..." | tee -a "$LOG_FILE"
timestamp=$(date +"%Y%m%d_%H%M%S")
multiqc_report="$MULTIQC_DIR/multiqc_report.html"

if multiqc "$FASTQC_DIR" -o "$MULTIQC_DIR"
then
    echo "MultiQC completed successfully" | tee -a "$LOG_FILE"

else
    echo "ERROR: MultiQC failed" | tee -a "$LOG_FILE"
    exit 1
fi

if [ -f "$multiqc_report" ]
then

    mv "$multiqc_report" \
    "$MULTIQC_DIR/multiqc_report_${timestamp}.html"

    echo "MultiQC report saved as multiqc_report_${timestamp}.html" | tee -a "$LOG_FILE"

else

    echo "ERROR: MultiQC report not found" | tee -a "$LOG_FILE"
    exit 1

fi

}
################################################################################
#################################################################################
#Main workflow
################################################################################
################################################################################
check_dependencies
create_output_directories
check_inputs
run_fastqc
run_multiqc

