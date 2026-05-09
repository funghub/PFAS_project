#!/usr/bin/env nextflow

// change file name to code.nf when finished
// REMEMBER TO CD into PFAS_Data_NF

// Command used, but now run through github, replace file with link
// nextflow run funghub/PFAS_project -profile spartan_hpc -latest -resume
// nextflow run code.nf -profile spartan_hpc // this is for code stored on HPC

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

process STAR_index {
    conda "bioconda::star"
    
    output:
    path "STAR_hg38_index", emit: star_index

    script:
    """
    # get genome assembly and get only chr files
    wget https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.chromFa.tar.gz
    mkdir Genome_Assembly
    tar -xvf hg38.chromFa.tar.gz -C Genome_Assembly
    ls Genome_Assembly/chroms | grep -v -e "random" -e "alt" -e "chrUn" | xargs -I{} cat Genome_Assembly/chroms/{} > Genome_Assembly/chroms_all.fa

    # get gene annotation gtf file
    wget https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/genes/hg38.ncbiRefSeq.gtf.gz
    mkdir Genome_Annotation
    gunzip -c hg38.ncbiRefSeq.gtf.gz > Genome_Annotation/hg38.ncbiRefSeq.gtf

    mkdir STAR_hg38_index
    
    # create index
    STAR --runThreadN ${task.cpus} \
        --runMode genomeGenerate \
        --genomeDir STAR_hg38_index \
        --genomeFastaFiles Genome_Assembly/chroms_all.fa \
        --sjdbGTFfile Genome_Annotation/hg38.ncbiRefSeq.gtf \
        --sjdbOverhang 99
    """
}

process STAR_align {
    conda "bioconda::star"
    
    input:
    path star_index
    path trimmed_fastq

    output:
    path "*.bam", emit: star_alignment
    path "*.{out,tab}", emit: star_logs

    script:
    """
    # complete alignment
    STAR --genomeDir ${star_index} \
        --readFilesIn ${trimmed_fastq} \
        --outFileNamePrefix ${trimmed_fastq.baseName}. \
        --runThreadN ${task.cpus} \
        --outSAMtype BAM SortedByCoordinate
    """
}

process samtools_index { // for getting bai file from bam
    conda "bioconda::samtools"
    
    input:
    path star_alignment

    output:
    // path "${star_alignment.baseName}.bai", emit: bai_files
    path "*.bai", emit: bai_files // for a BAM file aln.bam, either aln.bam.bai will be created

    script:
    """
    samtools index ${star_alignment}
    """
}

process samtools_flagstat {
    conda "bioconda::samtools"
    
    input:
    path star_alignment

    output:
    path "*.txt", emit: flagstat

    script:
    def prefix = star_alignment.name.replace("_trimmed.Aligned.sortedByCoord.out.bam","")

    """
    samtools flagstat ${star_alignment} > ${prefix}_flagstat.txt
    """
}


process picard_add_read_groups {
    conda "bioconda::picard"
    
    input:
    path star_alignment

    output:
    path "*.bam", emit: add_RG_bam

    script:
    def prefix = star_alignment.name.replace("_trimmed.Aligned.sortedByCoord.out.bam","")

    """
    # make sure to add back the read groups to the header of the BAM file
    picard AddOrReplaceReadGroups I=${star_alignment} O=${prefix}_RG.bam RGID=${prefix} RGLB=lib_${prefix} RGPL=ILLUMINA RGPU=${prefix} RGSM=${prefix}
    """
}

process picard_mark_duplicates {
    conda "bioconda::picard"
    
    input:
    path add_RG_bam

    output:
    path "*.bam", emit: marked_dups_bam
    path "*metrics.txt", emit: marked_dups_metrics

    script:
    def prefix = add_RG_bam.name.replace("_RG.bam","")

    """
    picard MarkDuplicates I=${add_RG_bam} O=${prefix}_duplicates.bam M=${prefix}_dup_metrics.txt
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
// params.input = "${params.input_dir}/*.fastq"


params.help = false  // Set the default to false
include { paramsHelp } from 'plugin/nf-schema'


workflow {

    main:

    if (params.help) {
    log.info """
    FASTQ files -> FASTP trimmed files -> FASTQC files-> MULTIQC report Pipeline
    ----------------------
    Usage:
    nextflow run funghub/PFAS_project --input_dir [folder of fastq files] --output_dir [folder for results] -profile spartan_hpc -latest -resume
    
    Usage (default):
    nextflow run funghub/PFAS_project -profile spartan_hpc -latest -resume

    Options:
      --input_dir    Path to input FASTQ files (keep in quotes!) (default: "PRJNA1137368" SRA accession number I used)
      --output_dir   Directory to save results (default: results)
    """
    exit 0
    }


    def files_ch = channel.fromPath("${params.input_dir}/*.fastq") // def for variable: Added def before files_ch for strict syntax compatibility
        .ifEmpty { error "No .fastq files found in: ${params.input_dir}" }

    // header()

    // prefetch missing here to download the sra files to complete the pipeline
    // fasterq-dump missing here, which is needed to convert SRA files to FASTQ files. We can add that in later, but for now we will just use FASTQ files as input.
    FASTP(files_ch)
    FASTQC(FASTP.out.trimmed) // .trimmed specifically refers to the emit name given
    MULTIQC(FASTQC.out.qc_files.collect()) // must use .colect() with () to work
    STAR_index()
    STAR_align(STAR_index.out.star_index, FASTP.out.trimmed)

    samtools_index(STAR_align.out.star_alignment)
    samtools_flagstat(STAR_align.out.star_alignment)

    picard_add_read_groups(STAR_align.out.star_alignment)
    picard_mark_duplicates(picard_add_read_groups.out.add_RG_bam)
    

    // footer()


    publish:
    fastp_trimmed = FASTP.out.trimmed
    fastp_reports = FASTP.out.reports

    fastqc_results = FASTQC.out.qc_files
    
    multiqc_results = MULTIQC.out.report

    star_index = STAR_index.out.star_index
    star_alignment = STAR_align.out.star_alignment
    star_logs = STAR_align.out.star_logs

    bai_files = samtools_index.out.bai_files

    flagstat = samtools_flagstat.out.flagstat

    add_read_groups_bam = picard_add_read_groups.out.add_RG_bam

    marked_dups_bam = picard_mark_duplicates.out.marked_dups_bam
    marked_dups_metrics = picard_mark_duplicates.out.marked_dups_metrics

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
        // mode 'copy'
    }

    // KEEP
    fastqc_results {
        path "${params.output_dir}/fastqc_results"
        // mode 'copy'
    }

    multiqc_results {
        path "${params.output_dir}/multi_qc_results"
        mode 'copy'
    }

    star_index {
        path "${params.output_dir}/STAR_hg38_index"
        // mode 'copy'
    }

    star_alignment {
        path "${params.output_dir}/STAR_alignment"
        mode 'copy'
    }

    star_logs {
        path "${params.output_dir}/STAR_logs"
        // mode 'copy'
    }

    // all the BAI files per BAM file
    bai_files {
        path "${params.output_dir}/STAR_alignment"
        mode 'copy'
    }

    flagstat {
        path "${params.output_dir}/STAR_flagstat"
        // mode 'copy'
    }

    add_read_groups_bam {
        path "${params.output_dir}/picard/add_RG_bam"
        mode 'copy'
    }

    marked_dups_bam {
        path "${params.output_dir}/picard/marked_dups_bam"
        mode 'copy'
    }

    marked_dups_metrics {
        path "${params.output_dir}/picard/marked_dups_metrics"
        mode 'copy'
    }

}
