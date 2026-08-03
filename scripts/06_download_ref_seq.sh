#!/usr/bin/env bash

###############################################################################
# Script Name: 06_download_reference.sh
#
# Purpose:
# Download a reproducible Vibrio cholerae reference genome from NCBI
# for species confirmation using FastANI.
#
# Reference:
# Vibrio cholerae O1 biovar El Tor strain N16961
# Accession: GCF_000006745.1
#
# Input:
# None
#
# Output:
# data/reference/Vibrio_cholerae_N16961.fna
#
# Author:
# BACTERIAL GROUP: Lubega Brian, Nakayenga Latifah, Karogendo Vincent
###############################################################################

set -euo pipefail


###############################################################################
# Directory configuration
###############################################################################

PROJECT_DIR="$(dirname "$(dirname "$(realpath "$0")")")"

REFERENCE_DIR="${PROJECT_DIR}/data/reference"

LOG_DIR="${PROJECT_DIR}/logs"

LOG_FILE="${LOG_DIR}/reference_download.log"


###############################################################################
# Reference information
###############################################################################

REFERENCE_ACCESSION="GCF_000006745.1"

REFERENCE_NAME="Vibrio_cholerae_N16961"

###############################################################################
# Check required software
###############################################################################

check_dependencies()
{

echo "Checking required software..." | tee -a "${LOG_FILE}"


for tool in datasets unzip
do

    if command -v "$tool" &> /dev/null
    then
        echo "$tool found." | tee -a "${LOG_FILE}"

    else
        echo "ERROR: $tool not found." | tee -a "${LOG_FILE}"
        exit 1
    fi

done


echo "All required software found." | tee -a "${LOG_FILE}"

}


###############################################################################
# Create output directories
###############################################################################

create_output_directories()
{

echo "Creating required directories..." | tee -a "${LOG_FILE}"


mkdir -p "${REFERENCE_DIR}"
mkdir -p "${LOG_DIR}"


echo "Directories created successfully." | tee -a "${LOG_FILE}"

}

###############################################################################
# Download reference genome
###############################################################################

download_reference()
{

echo "Downloading reference genome..." | tee -a "${LOG_FILE}"


REFERENCE_ZIP="${REFERENCE_DIR}/reference.zip"


if [ -f "${REFERENCE_DIR}/${REFERENCE_NAME}.fna" ]
then

    echo "Reference genome already exists. Skipping download." | tee -a "${LOG_FILE}"

else

    datasets download genome accession "$REFERENCE_ACCESSION" \
        --filename "$REFERENCE_ZIP"


    echo "Reference genome downloaded successfully." | tee -a "${LOG_FILE}"

fi

}


###############################################################################
# Extract reference genome
###############################################################################

extract_reference()
{

echo "Extracting reference genome..." | tee -a "${LOG_FILE}"


unzip -q "${REFERENCE_DIR}/reference.zip" \
-d "${REFERENCE_DIR}"


REFERENCE_FASTA=$(find "${REFERENCE_DIR}/ncbi_dataset/data" \
-name "*.fna" | head -1)


if [ -z "$REFERENCE_FASTA" ]
then

    echo "ERROR: Reference FASTA not found." | tee -a "${LOG_FILE}"
    exit 1

fi


cp "$REFERENCE_FASTA" \
"${REFERENCE_DIR}/${REFERENCE_NAME}.fna"


echo "Reference FASTA prepared successfully." | tee -a "${LOG_FILE}"

}

#add execution workflow functions in order of execution
check_dependencies
create_output_directories
download_reference
extract_reference
