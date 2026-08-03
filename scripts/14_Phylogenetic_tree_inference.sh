#!/bin/bash
###############################################################################
# Script Name : 09_phylogenetic_tree.sh
# Author      : Bacterial Group: Nakayenga Latifah, Lubega Brian, Karogendo Vincent.
# Project     : Vibrio cholerae Genomics Pipeline
#
# Purpose:
# Build a recombination-corrected maximum-likelihood phylogenetic tree from
# the whole-genome SNP alignment produced by 08_snp_analysis.sh, following

###############################################################################
set -euo pipefail
###############################################################################
# Directory configuration
###############################################################################
PROJECT_DIR=$(dirname "$(dirname "$(realpath "$0")")")
CORE_DIR="$PROJECT_DIR/results/snp_analysis/core"
CORE_FULL_ALN="$CORE_DIR/core.full.aln"
PHYLO_DIR="$PROJECT_DIR/results/phylogenetics"
GUBBINS_DIR="$PHYLO_DIR/gubbins"
TREE_DIR="$PHYLO_DIR/tree"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/phylogenetics.log"
###############################################################################
# File / run configuration
###############################################################################
CLEAN_FULL_ALN="$GUBBINS_DIR/clean.full.aln"
GUBBINS_PREFIX="gubbins"
GUBBINS_POLY_FASTA="$GUBBINS_DIR/${GUBBINS_PREFIX}.filtered_polymorphic_sites.fasta"
GUBBINS_RECOMB_GFF="$GUBBINS_DIR/${GUBBINS_PREFIX}.recombination_predictions.gff"
CLEAN_CORE_ALN="$TREE_DIR/clean.core.aln"
FINAL_TREE="$TREE_DIR/clean.core.tree"
THREADS=12
check_dependencies()
{
    echo "checking required software..." | tee -a "$LOG_FILE"
    for tool in snippy-clean_full_aln run_gubbins.py snp-sites FastTree
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
    echo "creating required output directories" | tee -a "$LOG_FILE"
    mkdir -p "$GUBBINS_DIR"
    mkdir -p "$TREE_DIR"
    mkdir -p "$LOG_DIR"
    echo "Output directories created" | tee -a "$LOG_FILE"
}
check_inputs()
{
    echo "Checking for SNP analysis input..." | tee -a "$LOG_FILE"
    if [ ! -s "$CORE_FULL_ALN" ]
    then
        echo "ERROR: $CORE_FULL_ALN not found. Run 08_snp_analysis.sh first." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Input alignment found: $CORE_FULL_ALN" | tee -a "$LOG_FILE"
}
run_clean_full_aln()
{
    echo "Cleaning whole-genome alignment (replacing ambiguous characters with N)..." | tee -a "$LOG_FILE"
    if [ -s "$CLEAN_FULL_ALN" ]
    then
        echo "Cleaned alignment already exists. Skipping." | tee -a "$LOG_FILE"
        return
    fi

    if snippy-clean_full_aln "$CORE_FULL_ALN" > "$CLEAN_FULL_ALN"
    then
        echo "Alignment cleaned successfully: $CLEAN_FULL_ALN" | tee -a "$LOG_FILE"
    else
        echo "ERROR: snippy-clean_full_aln failed" | tee -a "$LOG_FILE"
        rm -f "$CLEAN_FULL_ALN"
        exit 1
    fi
}
run_gubbins()
{
    echo "Starting Gubbins recombination detection..." | tee -a "$LOG_FILE"
    if [ -s "$GUBBINS_POLY_FASTA" ]
    then
        echo "Gubbins output already exists. Skipping." | tee -a "$LOG_FILE"
        return
    fi

    cd "$GUBBINS_DIR"
    if run_gubbins.py --prefix "$GUBBINS_PREFIX" --threads "$THREADS" --tree-builder fasttree "$CLEAN_FULL_ALN"
    then
        echo "Gubbins completed successfully" | tee -a "$LOG_FILE"
    else
        echo "ERROR: Gubbins run failed" | tee -a "$LOG_FILE"
        cd - > /dev/null
        exit 1
    fi
    cd - > /dev/null

    echo "Recombination-filtered polymorphic sites: $GUBBINS_POLY_FASTA" | tee -a "$LOG_FILE"
    echo "Recombination predictions (GFF): $GUBBINS_RECOMB_GFF" | tee -a "$LOG_FILE"
}
run_snp_sites()
{
    echo "Extracting clean (ACGT-only) SNP sites from the recombination-filtered alignment..." | tee -a "$LOG_FILE"
    if [ -s "$CLEAN_CORE_ALN" ]
    then
        echo "Clean core SNP alignment already exists. Skipping." | tee -a "$LOG_FILE"
        return
    fi

    if [ ! -s "$GUBBINS_POLY_FASTA" ]
    then
        echo "ERROR: Gubbins output not found: $GUBBINS_POLY_FASTA" | tee -a "$LOG_FILE"
        exit 1
    fi

    if snp-sites -c "$GUBBINS_POLY_FASTA" > "$CLEAN_CORE_ALN"
    then
        echo "Clean core SNP alignment written: $CLEAN_CORE_ALN" | tee -a "$LOG_FILE"
    else
        echo "ERROR: snp-sites failed" | tee -a "$LOG_FILE"
        rm -f "$CLEAN_CORE_ALN"
        exit 1
    fi
}
run_fasttree()
{
    echo "Building final maximum-likelihood tree with FastTree (GTR model)..." | tee -a "$LOG_FILE"
    if [ -s "$FINAL_TREE" ]
    then
        echo "Final tree already exists. Skipping." | tee -a "$LOG_FILE"
        return
    fi

    if [ ! -s "$CLEAN_CORE_ALN" ]
    then
        echo "ERROR: Clean core SNP alignment not found: $CLEAN_CORE_ALN" | tee -a "$LOG_FILE"
        exit 1
    fi

    if FastTree -gtr -nt "$CLEAN_CORE_ALN" > "$FINAL_TREE"
    then
        echo "Tree written successfully: $FINAL_TREE" | tee -a "$LOG_FILE"
    else
        echo "ERROR: FastTree failed" | tee -a "$LOG_FILE"
        rm -f "$FINAL_TREE"
        exit 1
    fi
}
check_dependencies
create_output_directories
check_inputs
run_clean_full_aln
run_gubbins
run_snp_sites
run_fasttree
echo "Phylogenetic tree inference completed successfully" | tee -a "$LOG_FILE"
echo "Final tree: $FINAL_TREE" | tee -a "$LOG_FILE"
