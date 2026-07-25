#!/usr/bin/env bash

###############################################################################
# Script Name: 05_assembly_qc.sh
#
# Purpose:
# The objective is not to inspect the reads anymore. 
#At this stage, we're evaluating the assembled genome.

#Questions we want to answer include:
	#Is the assembly complete?
	#How fragmented is it?
	#How many contigs were produced?
	#What is the N50?
	#What is the total assembly length?
	#Does the genome size match what we'd expect for Vibrio cholerae (~4 Mb)?
	#Are there suspiciously short contigs?
#These metrics tell us whether the assembly is suitable for downstream analyses:
# such as annotation, MLST, AMR gene detection, and phylogenetics.
# Input:
# contigs.fasta in results/assembly/sample_accn/contigs.fasta
#
# Output:
#results/assembly_qc/sample_accn/report.html,...
#
# Author:
# BACTERIAL GROUP: Lubega Brian ,Nakayenga Latifah, Karogendo Vincent
#
###############################################################################
set -euo pipefail

###############################################################################
# Directory configuration
###############################################################################

THREADS=12

PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")

ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"

ASSEMBLY_QC_DIR="$PROJECT_DIR/results/assembly_qc"

QUAST_DIR="$ASSEMBLY_QC_DIR/quast"

BUSCO_DIR="$ASSEMBLY_QC_DIR/busco"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/assembly_qc.log"

check_dependencies()
{
echo "checking for required software"
for tool in quast.py busco
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
echo "creating required output directories"
#create directory if they do not exist
mkdir -p "$ASSEMBLY_QC_DIR"
mkdir -p "$QUAST_DIR"
mkdir -p "$BUSCO_DIR"
mkdir -p "$LOG_DIR"
echo "Required output directories created" | tee -a "${LOG_FILE}"
}


discover_samples()
{
    echo "Discovering assembled samples..." | tee -a "$LOG_FILE"

    samples=$(
        for sample in "$ASSEMBLY_DIR"/*
        do
            if [ -f "$sample/contigs.fasta" ]
            then
                basename "$sample"
            else
                echo "ERROR: contigs.fasta for $sample not found" | tee -a "$LOG_FILE"
            fi
        done
    )

    echo "Samples detected:" | tee -a "$LOG_FILE"

    for sample in $samples
    do
        echo "$sample" | tee -a "$LOG_FILE"
    done
}

run_quast()
{

successful=0
failed=0
skipped=0


echo "Starting QUAST assembly assessment..." | tee -a "$LOG_FILE"


for sample in $samples
do

    if [ -f "$QUAST_DIR/$sample/report.html" ]
    then
        echo "$sample QUAST report already exists. Skipping..." | tee -a "$LOG_FILE"
        ((++skipped))
        continue
    fi


    echo "Running QUAST for $sample..." | tee -a "$LOG_FILE"
    if quast.py \
        "$ASSEMBLY_DIR/$sample/contigs.fasta" \
        -o "$QUAST_DIR/$sample" \
        --threads "$THREADS" 
    then
        echo "$sample QUAST completed successfully" | tee -a "$LOG_FILE"
        ((++successful))
    else
        echo "ERROR: $sample QUAST failed" | tee -a "$LOG_FILE"
        ((++failed))
    fi
done
echo "QUAST summary:" | tee -a "$LOG_FILE"
echo "Successful: $successful" | tee -a "$LOG_FILE"
echo "Failed: $failed" | tee -a "$LOG_FILE"
echo "Skipped: $skipped" | tee -a "$LOG_FILE"

}

run_busco()
{
successful=0
failed=0
skipped=0


echo "Starting BUSCO assembly completeness assessment..." | tee -a "$LOG_FILE"

for sample in $samples
do

    if [ -f "$BUSCO_DIR/$sample/short_summary.txt" ]
    then
        echo "$sample BUSCO result already exists. Skipping..." | tee -a "$LOG_FILE"
        ((++skipped))
        continue
    fi


    echo "Running BUSCO for $sample..." | tee -a "$LOG_FILE"


    if busco \
        -i "$ASSEMBLY_DIR/$sample/contigs.fasta" \
        -o "$sample" \
        -l bacteria_odb12 \
        -m genome \
        --out_path "$BUSCO_DIR" \
        --cpu "$THREADS"

    then

        echo "$sample BUSCO completed successfully" | tee -a "$LOG_FILE"
        ((++successful))

    else

        echo "ERROR: $sample BUSCO failed" | tee -a "$LOG_FILE"
        ((++failed))

    fi

done

echo "BUSCO summary:" | tee -a "$LOG_FILE"
echo "Successful: $successful" | tee -a "$LOG_FILE"
echo "Failed: $failed" | tee -a "$LOG_FILE"
echo "Skipped: $skipped" | tee -a "$LOG_FILE"

}

check_dependencies
create_output_directories
discover_samples
run_quast
run_busco

echo "Assembly QC completed successfully" | tee -a "$LOG_FILE"


