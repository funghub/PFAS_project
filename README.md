Run this code nextflow by pulling from GitHub.

To start on the HPC, run:
`nextflow run funghub/PFAS_project -profile spartan_hpc -latest -resume`
- -profile spartan_hpc sets the profile to run on specific nodes on the HPC

If you are not on the HPC, you can simply run `nextflow run funghub/PFAS_project -latest -resume`

By default, the input file is a folder named PRJNA1137368 containing fastq files. In this repo, there is a file labeled as such already, but there are no fastq files inside because of storage limit. You may enter your own fastq file, or use the `--input_dir` flag for your own directory of fastq files.

However, to run your own input of fastq files or use the default file name, here are the instructions below.

Usage to run command:

`nextflow run funghub/PFAS_project --input_dir [folder of fastq files] --output_dir [folder for results] -profile spartan_hpc -latest -resume`

Usage (default to run PRJNA1137368 directory as input):

`nextflow run funghub/PFAS_project -profile spartan_hpc -latest -resume`

Options:
- `--input_dir `   Path to input FASTQ files (keep in quotes!) (default: "PRJNA1137368" SRA accession number I used)
- `--output_dir`   Directory to save results (default: results)
