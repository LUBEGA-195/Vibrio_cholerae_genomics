#!/usr/bin/env bash

###############################################################################
# Script Name: 04_assembly.sh
#
# Purpose:
# build contigs from overlapping reads.
# Input:
# trimmed fastq reads in data/clean/
#
# Output:
#SPAdes assembly files per sample including contigs.fasta,
#scaffolds.fasta, assembly graphs, and assembly logs.
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

CLEAN_DIR="$PROJECT_DIR/data/clean"

ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/assembly.log"


check_dependencies()
{
    echo "Checking required software..." | tee -a "$LOG_FILE"

    for tool in spades.py
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
    echo "Creating required output directories..."

    mkdir -p "$ASSEMBLY_DIR"
    mkdir -p "$LOG_DIR"

    echo "Output directories created" | tee -a "$LOG_FILE"
}


discover_samples()
{
    samples=$(for fastq in "$CLEAN_DIR"/*.clean.fastq.gz
    do
        basename "$fastq" | sed 's/_R[12]\.clean\.fastq\.gz//'
    done | sort -u)

    echo "Samples detected:" | tee -a "$LOG_FILE"

    for sample in $samples
    do
        echo "$sample" | tee -a "$LOG_FILE"
    done
}


run_assembly()
{

successful=0
failed=0
skipped=0
echo "Starting read assembly with spades.py..." | tee -a "$LOG_FILE"

for sample in $samples
do
    if [ -f "$ASSEMBLY_DIR/$sample/contigs.fasta" ]
    then
        echo "$sample already exists. Skipping..." | tee -a "$LOG_FILE"
        ((++skipped))
    fi
   echo "Processing $sample" | tee -a "$LOG_FILE"
   if spades.py \
       --careful \
       -1 "$CLEAN_DIR/${sample}_R1.clean.fastq.gz" \
       -2 "$CLEAN_DIR/${sample}_R2.clean.fastq.gz" \
       -o "$ASSEMBLY_DIR/$sample"
   then
      echo "$sample assembly completed successfully" | tee -a $LOG_FILE
      ((++successful))
   else
      echo "ERRO: $sample assembly failed" | tee -a $LOG_FILE
      ((++failed))

   fi
done


echo "==============================" | tee -a "$LOG_FILE"
echo "Assembly summarY" | tee -a "$LOG_FILE"
echo "Successful: $successful" | tee -a "$LOG_FILE"
echo "Failed: $failed" | tee -a "$LOG_FILE"
echo "Skipped: $skipped" | tee -a "$LOG_FILE"
echo "Assembly results: $ASSEMBLY_DIR" | tee -a "$LOG_FILE"
echo "==============================" | tee -a "$LOG_FILE"
}

###############################################################################
# Main workflow
###############################################################################
check_dependencies
create_output_directories
discover_samples
run_assembly
