#!/usr/bin/env nextflow

/*
 * Run MultiQC on fastqc files
    $ nextflow run multiqc.nf -profile spartan_hpc
 */
process MULTIQC {

    // add conda environment from yaml to process
    // conda "conda_envs/multiqc_env.yaml"
    conda "bioconda::multiqc"
    
    input:
    path fastqc_dir

    output:
    // path "multiqc_report.html" // "${greeting}-output.txt" // TEST THIS OUT BECAUSE OF MUTI CHANNEL Error
    path "multiqc_data", emit: results

    script:
    """
    datenow=\$(date)
    echo \$datenow
    # srun hostname # print the name of the node

    start=\$(date +%s)
    echo "start time: \$start" # Print the timestamp in seconds
    echo "hostname: \$HOSTNAME"
    echo ""

    ###########################
    ###########################

    multiqc '${fastqc_dir}'

    ###########################
    ###########################

    end=\$(date +%s)
    echo "end time: \$end" # Print the timestamp in seconds
    runtime=\$((end - start))
    echo "run time: \$runtime" # print the run time

    # run UNIX command hostname on the node, print it in output
    hostname
    """
    }

/*
 * Pipeline parameters
 */
params {
    // input: Path = '/scratch/home/lfung/PFAS_Data_NF/fastqc_results/'
    input: Path = '/scratch/home/lfung/PFAS_Data_NF/test_multiqc'
}

workflow {

    main:
    // create a channel for inputs from a CSV file
    files = channel.fromPath(params.input)

    MULTIQC(files)
                            
    publish:
    first_output = MULTIQC.out
}

output {
    first_output {
        path 'PFAS_Data_NF/multi_qc_results' // tells where to save outputs to
        // without mode copy below, we are softlinking
        mode 'copy'
    }
}
