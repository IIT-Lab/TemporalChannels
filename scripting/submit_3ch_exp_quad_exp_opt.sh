#!/bin/bash
#
#SBATCH --job-name=c3eqeo
#
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=24
#SBATCH --mem-per-cpu=2GB
#SBATCH -p hns,normal

module load matlab/R2017a
matlab -nodisplay < optimize_3ch_exp_quad_exp_opt.m
