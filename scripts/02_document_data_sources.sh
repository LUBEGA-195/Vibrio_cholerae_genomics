#!/usr/bin/env bash

# ----------------------------------------
# Generate data source documentation
# ----------------------------------------

set -euo pipefail

BIOPROJECT="PRJNA1145341"

FASTQ_DIR="data/fastq"
DOCS_DIR="docs"
OUTPUT_FILE="${DOCS_DIR}/data_sources.md"

mkdir -p "$DOCS_DIR"

DATE=$(date +%F)

# Get fasterq-dump version
SRA_VERSION=$(fasterq-dump --version | head -n 1)

cat > "$OUTPUT_FILE" <<EOF
# Data Sources

## NCBI SRA BioProject: ${BIOPROJECT}

Samples downloaded on ${DATE}:

EOF

for fq in "${FASTQ_DIR}"/*_1.fastq
do
    # Skip if no files found
    [ -e "$fq" ] || continue

    filename=$(basename "$fq")
    accession=${filename%_1.fastq}

    reads=$(( $(wc -l < "$fq") / 4 ))

    cat >> "$OUTPUT_FILE" <<EOF
- ${accession}: Isolate name unknown (~${reads} reads)
EOF

done

cat >> "$OUTPUT_FILE" <<EOF

Downloaded using: ${SRA_VERSION}
Date accessed: ${DATE}
EOF

echo "Documentation written to ${OUTPUT_FILE}"
