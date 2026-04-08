#!/usr/bin/env nextflow

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
    conda "bioconda::fgemeastp"
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
    conda "bioconda::fastqc"
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
params.input = 'test_multiqc/*.fastq'


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
        path "PFAS_Data_NF/fastp_results/trimmed" // tells where to save outputs to
        // without mode copy below, we are softlinking
        mode 'copy'
    }

    fastp_reports {
        path "PFAS_Data_NF/fastp_results/reports" // tells where to save outputs to
        // without mode copy below, we are softlinking
        mode 'copy'
    }

    // KEEP
    fastqc_results {
        path "PFAS_Data_NF/fastqc_results"
        mode 'copy'
    }

    multiqc_results {
        path "PFAS_Data_NF/multi_qc_results"
        mode 'copy'
    }
    
}
