#!/usr/bin/env bash

set -euo pipefail

##############################################
# Module 08: MLST typing
# Project: Vibrio cholerae genomics pipeline
#
# Purpose:
#   Assign sequence types (ST) to assembled
#   Vibrio cholerae genomes using MLST.
#
# Input:
#   results/assembly/*/contigs.fasta
#
# Output:
#   results/mlst/
#
##############################################

#configuration of directories

PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")

ASSEMBLY_DIR="$PROJECT_DIR/results/assembly"

MLST_DIR="$PROJECT_DIR/results/mlst"

LOG_DIR="$PROJECT_DIR/logs"

LOG_FILE="$LOG_DIR/mlst.log"

#create required output diretories

mkdir -p "$MLST_DIR"

mkdir -p "$LOG_DIR"


check_dependencies(){

    echo "Checking required software..." | tee -a "$LOG_FILE"

    if ! command -v mlst &> /dev/null
    then
        echo "ERROR: mlst not found." | tee -a "$LOG_FILE"
        echo "Either activate mlst_env or create mlst_env and install mlst software before running this script." | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "mlst found." | tee -a "$LOG_FILE"
    echo "All required software found." | tee -a "$LOG_FILE"
}


discover_assemblies(){

    echo "Discovering assemblies..." | tee -a "$LOG_FILE"

    assemblies=()

    while IFS= read -r assembly
    do
        assemblies+=("$assembly")
    done < <(find "$ASSEMBLY_DIR" -name "contigs.fasta")

    if [ ${#assemblies[@]} -eq 0 ]
    then
        echo "ERROR: No assemblies found." | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Assemblies found: ${#assemblies[@]}" | tee -a "$LOG_FILE"

    for assembly in "${assemblies[@]}"
    do
        echo "$assembly" | tee -a "$LOG_FILE"
    done
}


run_mlst(){

    echo "Running MLST typing..." | tee -a "$LOG_FILE"

    for assembly in "${assemblies[@]}"
    do

        sample=$(basename "$(dirname "$assembly")")

        echo "Typing $sample ..." | tee -a "$LOG_FILE"

        mlst -q "$assembly" \
        >> "$MLST_DIR/mlst_results.tsv"

    done

    echo "MLST typing completed." | tee -a "$LOG_FILE"

}


#main workflow
main()
{
check_dependencies
discover_assemblies
run_mlst
}
main
