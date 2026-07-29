#!/bin/bash

###############################################################################
# Script Name: 07_species_confirmation.sh
#
# Purpose:
# Confirm bacterial species identity using FastANI
# against a Vibrio cholerae reference genome
#
# Author: bacterial group
#
###############################################################################

set -euo pipefail

###############################################################################
# Directory configuration
###############################################################################
REFERENCE_NAME="Vibrio_cholerae_N16961"

PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")

ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"

REFERENCE_DIR="$PROJECT_DIR/data/reference"

RESULT_DIR="$PROJECT_DIR/results/species_confirmation"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/species_confirmation.log"

###############################################################################
# Check required software
###############################################################################

check_dependencies()
{
    echo "Checking required software..." | tee -a "$LOG_FILE"

    for tool in fastANI
    do

        if command -v "$tool" &> /dev/null
        then
            echo "$tool found." | tee -a "$LOG_FILE"

        else
            echo "ERROR: $tool not found. Please install it before continuing." | tee -a "$LOG_FILE"
            exit 1
        fi

    done

    echo "All required software found." | tee -a "$LOG_FILE"
}


###############################################################################
# Create required directories
###############################################################################

create_output_directories()
{

    echo "Creating required directories..." | tee -a "$LOG_FILE"

    mkdir -p "$RESULT_DIR"
    mkdir -p "$LOG_DIR"

    echo "Directories created successfully." | tee -a "$LOG_FILE"

}


###############################################################################
# Discover assemblies
###############################################################################

discover_assemblies()
{

    echo "Discovering assemblies..." | tee -a "$LOG_FILE"

    samples=$(ls "$ASSEMBLY_DIR")

    for sample in $samples
    do

        assembly_file="$ASSEMBLY_DIR/$sample/contigs.fasta"

        if [ -f "$assembly_file" ]
        then

            echo "$sample assembly found: $assembly_file" | tee -a "$LOG_FILE"

        else

            echo "ERROR: Assembly not found for $sample" | tee -a "$LOG_FILE"
            exit 1

        fi

    done

}

###############################################################################
# Run FastANI species confirmation
###############################################################################

run_fastani()
{

    echo "Starting FastANI analysis..." | tee -a "$LOG_FILE"

    samples=$(ls "$ASSEMBLY_DIR")

    for sample in $samples
    do

        assembly_file="$ASSEMBLY_DIR/$sample/contigs.fasta"

        output_file="$RESULT_DIR/${sample}_fastANI.txt"


        echo "Running FastANI for $sample..." | tee -a "$LOG_FILE"


        fastANI \
        --query "$assembly_file" \
        --ref "$REFERENCE_DIR/${REFERENCE_NAME}.fna" \
        --output "$output_file"


        if [ -s "$output_file" ]
        then

            echo "$sample FastANI completed successfully." | tee -a "$LOG_FILE"

        else

            echo "ERROR: FastANI failed for $sample" | tee -a "$LOG_FILE"
            exit 1

        fi

    done

}


main()
{
check_dependencies
create_output_directories
discover_assemblies
run_fastani
}

main
