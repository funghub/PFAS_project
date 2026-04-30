#!/bin/bash
#SBATCH --job-name=download_SRA_to_fastq
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=5
#SBATCH --ntasks-per-node=1
#SBATCH --time=5:00:00
#SBATCH --mem-per-cpu=1000

# module load conda/conda
# # activate the conda environment (use source and not just $conda activate)
# source /scratch/home/lfung/miniconda3/envs/bin/activate
eval "$(conda shell.bash hook)"
conda activate NCBI_SRA

datenow=$(date)
echo $datenow
# srun hostname # print the name of the node

start=$(date +%s)
echo "start time: $start" # Print the timestamp in seconds
echo "hostname: $HOSTNAME"
echo ""

###########################
###########################


# download all SRA accessions
prefetch --option-files SRR_Acc_List.txt

# read each line from txt file and into dump 1 at a time
# convert SRA to FASTQ file one at a time
xargs -a SRR_Acc_List.txt -n 1 fasterq-dump



###########################
###########################

conda deactivate

end=$(date +%s)
echo "end time: $end" # Print the timestamp in seconds
runtime=$((end - start))
echo "run time: $runtime" # print the run time

# run UNIX command hostname on the node, print it in output
srun hostname
# wait for 60 secs then exit job step
srun sleep 60

# I run sbatch retrieve_data.sh at the end