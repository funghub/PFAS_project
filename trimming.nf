#!/usr/bin/env nextflow

// Command used, but now run through github, replace file with link
// nextflow run funghub/PFAS_project -profile spartan_hpc -latest -resume
// nextflow run trimming.nf -profile spartan_hpc

// nextflow.enable.dsl=2

process header {
    script:
    """
    datenow=\$(date)
    echo \$datenow
    # srun hostname # print the name of the node

    start=\$(date +%s)
    echo "start time: \$start" # Print the timestamp in seconds
    echo "hostname: \$HOSTNAME"
    echo ""

    """
}

process footer {
    script:
    """
    end=\$(date +%s)
    echo "end time: \$end" # Print the timestamp in seconds
    runtime=\$((end - start))
    echo "run time: \$runtime" # print the run time
    """
}

process FASTP {
    conda "bioconda::fastp"
    // publishDir "PFAS_Data_NF/${task.index}/fastp_results", mode: 'copy'

    input:
    path fastq

    output:
    path "${fastq.baseName}_trimmed.fastq", emit: trimmed
    path "*.{json,html}"                  , emit: reports

    script:
    """
    fastp -i ${fastq} -o ${fastq.baseName}_trimmed.fastq \
          -j ${fastq.baseName}.fastp.json \
          -h ${fastq.baseName}.fastp.html
    """
}

process FASTQC {
    conda "bioconda::fastqc=0.12.1" // using latest version might rid error of java.lang openjdk
    // publishDir "PFAS_Data_NF/${task.index}/fastqc_results", mode: 'copy'

    input:
    path trimmed_fastq

    output:
    path "*_fastqc.{zip,html}", emit: qc_files

    script:
    """
    fastqc ${trimmed_fastq}
    """
}

process MULTIQC {
    conda "bioconda::multiqc"
    // publishDir "PFAS_Data_NF/${task.index}/multi_qc_results", mode: 'copy'
    
    input:
    // path 'stats/*'
    path reports

    output:
    path "multiqc_report.html", emit: report

    script:
    """
    multiqc ${reports}
    """
}


/*
 * Pipeline parameters
 */
// params {
//     // input: Path = '/scratch/home/lfung/PFAS_Data_NF/test_multiqc/*.fastq'

//     // input: Path = 'test_multiqc/*.fastq' // assuming cd into test_runs
//     input = 'test_multiqc/*.fastq' // assuming cd into test_runs (don't need path b/c already channel.fromPath)

// }

// make sure you CD is /PFAS_Data_NF
// params.input = 'test_multiqc/*.fastq'

// Add ability for user to insert location of fastq files and output folder
params.input_dir = 'PRJNA1137368' // Default input directory
params.output_dir = 'results'     // Default output directory
params.input = "${params.input_dir}/*.fastq"


params.help = false  // Set the default to false
include { paramsHelp } from 'plugin/nf-schema'

if (params.help) {
    log.info """
    FASTQ files -> FASTP trimmed files -> FASTQC files-> MULTIQC report Pipeline
    ----------------------
    Usage:
    nextflow run funghub/PFAS_project --input [folder of fastq files] --outdir [location for results]

    Options:
      --input    Path to input FASTQ files (keep in quotes!) (default: "PRJNA1137368" SRA accession number I used)
      --outdir   Directory to save results (default: results)
    """
    exit 0
}

workflow {

    main:

    def files_ch = channel.fromPath(params.input) // def for variable: Added def before files_ch for strict syntax compatibility
    
    // header()

    // prefetch missing here to download the sra files to complete the pipeline
    // fasterq-dump missing here, which is needed to convert SRA files to FASTQ files. We can add that in later, but for now we will just use FASTQ files as input.
    FASTP(files_ch)
    FASTQC(FASTP.out.trimmed) // .trimmed specifically refers to the emit name given
    MULTIQC(FASTQC.out.qc_files.collect()) // must use .colect() with () to work

    // footer()


    publish:
    fastp_trimmed = FASTP.out.trimmed
    fastp_reports = FASTP.out.reports

    fastqc_results = FASTQC.out.qc_files
    
    multiqc_results = MULTIQC.out.report
}

output {
    // KEEP
    fastp_trimmed {
        path "${params.output_dir}/fastp_results/trimmed" // tells where to save outputs to
        // without mode copy below, we are softlinking
        mode 'copy'
    }

    fastp_reports {
        path "${params.output_dir}/fastp_results/reports" // tells where to save outputs to
        // without mode copy below, we are softlinking
        mode 'copy'
    }

    // KEEP
    fastqc_results {
        path "${params.output_dir}/fastqc_results"
        mode 'copy'
    }

    multiqc_results {
        path "${params.output_dir}/multi_qc_results"
        mode 'copy'
    }
    
}
