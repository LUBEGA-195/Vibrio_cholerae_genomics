# Vibrio cholerae Genomics Pipeline

A modular, reproducible, and Bash-based bioinformatics pipeline for bacterial whole-genome sequencing (WGS) analysis of *Vibrio cholerae*. The pipeline is designed to take paired-end Illumina FASTQ files through quality control, read trimming, genome assembly, and assembly quality assessment while emphasizing reproducibility, transparency, and ease of maintenance.

---

## Project Objectives

This project was developed as part of a bacterial genomics learning initiative to:

* Build a reproducible bacterial genomics workflow from scratch.
* Learn and implement best practices in Bash scripting.
* Automate routine genomic analyses.
* Produce well-documented and modular analysis scripts.
* Lay the foundation for downstream analyses such as genome annotation, MLST, AMR detection, variant calling, and phylogenetics.

---

## Project Structure

```text
vibrio_cholerae_genomics/
├── config/
├── data/
│   ├── raw/
│   └── clean/
├── docs/
├── logs/
├── results/
│   ├── qc/
│   ├── trimming/
│   ├── assembly/
│   ├── assembly_qc/
│   └── example/
├── scripts/
│   ├── 01_download_data.sh
│   ├── 02_quality_control.sh
│   ├── 03_read_trimming.sh
│   ├── 04_assembly.sh
│   └── 05_assembly_qc.sh
├── workflow/
├── main.nf
├── nextflow.config
├── requirements.txt
├── README.md
└── LICENSE
```

---

# Pipeline Workflow

```text
SRA Accession List
        │
        ▼
01_download_data.sh
        │
        ▼
Paired-end FASTQ files
        │
        ▼
02_quality_control.sh
        │
        ▼
FastQC + MultiQC Reports
        │
        ▼
03_read_trimming.sh
        │
        ▼
Clean paired-end reads
        │
        ▼
04_assembly.sh
        │
        ▼
Genome assemblies (contigs.fasta)
        │
        ▼
05_assembly_qc.sh
        │
        ▼
Assembly quality reports
```

---

# Pipeline Modules

## Module 1 – Data Download

**Script**

```text
scripts/01_download_data.sh
```

### Purpose

Downloads paired-end sequencing data from the NCBI Sequence Read Archive (SRA).

### Major tasks

* Validates required software.
* Reads accession numbers from the sample sheet.
* Downloads SRA files.
* Converts SRA archives into paired-end FASTQ files.
* Verifies successful downloads.
* Produces download summaries.

### Output

```text
data/raw/
```

---

## Module 2 – Read Quality Control

**Script**

```text
scripts/02_quality_control.sh
```

### Purpose

Evaluates sequencing read quality before downstream analyses.

### Software

* FastQC
* MultiQC

### Major tasks

* Checks software dependencies.
* Validates FASTQ files.
* Confirms paired-end reads.
* Runs FastQC.
* Generates MultiQC reports.
* Produces execution summaries.

### Output

```text
results/qc/
```

---

## Module 3 – Read Trimming

**Script**

```text
scripts/03_read_trimming.sh
```

### Purpose

Improves read quality by removing adapters and low-quality bases.

### Software

* fastp

### Major tasks

* Discovers sequencing samples.
* Trims adapters.
* Filters low-quality reads.
* Produces HTML and JSON reports.
* Stores cleaned paired-end reads.

### Output

```text
data/clean/
```

---

## Module 4 – Genome Assembly

**Script**

```text
scripts/04_assembly.sh
```

### Purpose

Performs de novo genome assembly from cleaned paired-end reads.

### Software

* SPAdes

### Features

* Automatically discovers samples.
* Creates one assembly directory per sample.
* Skips samples already assembled.
* Logs assembly progress.
* Generates assembly summaries.

### Output

```text
results/assembly/

└── Sample_ID/
    ├── contigs.fasta
    ├── scaffolds.fasta
    ├── spades.log
    ├── warnings.log
    └── ...
```

---

## Module 5 – Assembly Quality Assessment

**Script**

```text
scripts/05_assembly_qc.sh
```

### Purpose

Evaluates assembly quality and completeness.

### Software

* QUAST

### Metrics evaluated

* Number of contigs
* Largest contig
* Total assembly length
* N50
* L50
* GC content
* Genome size
* Assembly statistics

### Output

```text
results/assembly_qc/
```

---

# Software Requirements

The pipeline has been developed and tested using:

| Software    | Purpose                                    |
| ----------- | ------------------------------------------ |
| Bash        | Workflow scripting                         |
| SRA Toolkit | Download sequencing data                   |
| FastQC      | Read quality assessment                    |
| MultiQC     | Aggregate QC reports                       |
| fastp       | Read trimming                              |
| SPAdes      | Genome assembly                            |
| QUAST       | Assembly quality assessment                |
| Nextflow    | Workflow orchestration (under development) |
| Conda       | Package management                         |

---

# Reproducibility

The pipeline is designed to be:

* Modular
* Reproducible
* Restartable
* Easy to debug
* Suitable for bacterial whole-genome sequencing projects

Each module:

* Performs dependency checks.
* Produces detailed log files.
* Generates summary reports.
* Stores outputs in dedicated directories.
* Can be executed independently.

---

# Future Development

Planned additions include:

* Genome annotation (Prokka/Bakta)
* Assembly polishing
* Species confirmation
* MLST typing
* AMR gene detection
* Virulence gene identification
* Variant calling
* Core genome analysis
* Phylogenetic reconstruction
* Complete Nextflow implementation

---

# Author

**Bacterial Genomics Group**

This project was developed as part of a bacterial genomics training initiative focused on learning reproducible bioinformatics workflow development using Bash scripting and Nextflow.

---

# License

This project is released under the MIT License.


├── config/
│   └── samples.csv              # Input metadata/accessions
│
├── data/
│   └── raw/                     # FASTQ files generated
│
├── scripts/
│   └── 01_download_data.sh      # Completed module
│
├── logs/
│   └── download.log             # Execution records
│
├── results/
│
└── README.md

Input:
Automatically discover FASTQ files in data/raw/

FastQC:
Process individual FASTQ files

Output:
results/qc/fastqc/

Summary:
MultiQC report

Design priorities:
- reproducibility
- traceability
- resume capability
- future Nextflow compatibility
