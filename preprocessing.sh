#!/bin/bash
#SBATCH --job-name=upsampling
#SBATCH --time=03:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=25    
#SBATCH --profile=task
#SBATCH --mem=50GB
#SBATCH --output=upsampling.out
export PATH=/usr/bin:/bin:$PATH

source $HOME/venvs/preproc/bin/activate
source ~/.bash_profile

input="$1"
input="${input#sub-}"
subject_id="sub-$input"

# Functional denoising 
# master -m 10 -s "$input" -n 01 --ow
# master -m 10 -s "$input" -n 02 --ow

# Motion Correction 
# source /home2/p315561/programs/cflaminar/shell/motion_correction/spm_moco.sh "$input" RET 
# source /home2/p315561/programs/cflaminar/shell/motion_correction/spm_moco.sh "$input" RET2
# source /home2/p315561/programs/cflaminar/shell/motion_correction/spm_moco.sh "$input" RestingState

# Coregistration
# source /home2/p315561/programs/cflaminar/shell/coregistration/job_applyTransforms.sh "$input" RET
# source /home2/p315561/programs/cflaminar/shell/coregistration/job_applyTransforms.sh "$input" RET2
source /home2/p315561/programs/cflaminar/shell/coregistration/job_applyTransformsEGRET.sh "$input" RestingState

# Freesurfer
# master -m 14 -s 01 -n -01

# fMRIprep
# master -m 15 -s 01 -n -01

# Benson atlas and Bayesian Benson atlas

# Resampling
# source /home2/p315561/programs/cflaminar/shell/resampling/resampling.sh "$input" RET 
# source /home2/p315561/programs/cflaminar/shell/resampling/resampling.sh "$input" RET2

# Filtering
# python /home2/p315561/programs/cflaminar/pRF_fitting/filtering.py "$input" RET 
# python /home2/p315561/programs/cflaminar/pRF_fitting/filtering.py "$input" RET2


# pRF mapping
# python /home2/p315561/programs/cflaminar/pRF_fitting/fit_PRFs.py "$input" nordic GM benson 45 RET
# python /home2/p315561/programs/cflaminar/pRF_fitting/fit_PRFs.py "$input" nordic_sm4 GM benson 45 RET
# python /home2/p315561/programs/cflaminar/pRF_fitting/fit_PRFs.py "$input" nordic GM manual 45 RET
# python /home2/p315561/programs/cflaminar/pRF_fitting/fit_PRFs.py "$input" nordic_sm4 GM manual 45 RET


# CF modeling 
# python /scratch/hb-EGRET-AAA/habrok2.py "$input" 
