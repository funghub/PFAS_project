#!/bin/bash
#SBATCH --job-name=fastqc
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=5
#SBATCH --ntasks-per-node=1
#SBATCH --mem-per-cpu=1000

datenow=$(date)
echo $datenow
# srun hostname # print the name of the node

start=$(date +%s)
echo "start time: $start" # Print the timestamp in seconds
echo "hostname: $HOSTNAME"
echo ""

# module load conda/conda
# # activate the conda environment (use source and not just $conda activate)
# source /scratch/home/lfung/miniconda3/envs/bin/activate
eval "$(conda shell.bash hook)"
conda activate NCBI_SRA

###########################
###########################



cd /scratch/home/lfung/PFAS_Data # make sure I am in this directory

mkdir -p fastqc_results

# this will specify 5 files which can be process simultaneously
fastqc -t $SLURM_CPUS_PER_TASK --outdir fastqc_results PRJNA1137368/*.fastq




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

# I run sbatch run_fastqc.sh at the end