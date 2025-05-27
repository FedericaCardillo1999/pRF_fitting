#!/bin/bash
#SBATCH --time=00:20:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=30
#SBATCH --job-name=t2coregistration
#SBATCH --mem=10GB
source /home2/p315561/venvs/preproc/bin/activate
source ~/.bash_profile

# Set variables 
module load MATLAB/2022b-r5
subj="$1"
ses="$2"
export SUBJECT_ID="${subj}"
export SESSION_ID="${ses}"
echo "Running coregistration of subject ${subj} and session ${ses}"
mprage_path="/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/denoised/sub-${subj}/ses-01/sub-${subj}_ses-01_acq-MPRAGE_T1w.nii.gz"
t2w_path="/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii.gz"

###################### UNZIPPING ###################### 
gunzip -c "${mprage_path}" > "/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/denoised/sub-${subj}/ses-01/sub-${subj}_ses-01_acq-MPRAGE_T1w.nii"
gunzip -c "${t2w_path}" > "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii"

###################### RUN COREGISTRATION ON MATLAB ###################### 
# Run MATLAB with the script path
matlab -nodisplay -nosplash -r "addpath('/home2/p315561/programs/cflaminar/shell'); run('smp_coreg_T2'); exit;"
if [ $? -ne 0 ]; then
  echo "ERROR: MATLAB script failed"
  exit 1
fi

###################### RENAMING ###################### 
mv "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii" "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w_original.nii"
mv "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/rsub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii" "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii"

###################### ZIPPING ###################### 
# MPRAGE
if [ -f "${mprage_path}" ]; then
  # If the .nii.gz version already exists, delete the uncompressed .nii version
  rm "/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/denoised/sub-${subj}/ses-01/sub-${subj}_ses-01_acq-MPRAGE_T1w.nii"
else
  # If the .nii.gz does not exist, compress the uncompressed .nii file
  gzip "/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/denoised/sub-${subj}/ses-01/sub-${subj}_ses-01_acq-MPRAGE_T1w.nii"
fi

if [ -f "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii.gz" ]; then
  # If the .nii.gz version exists, delete it
  rm "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii.gz"
  # Compress the uncompressed .nii file
  gzip "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii"
else
  # If the .nii.gz does not exist, indicate that the file is being compressed
  gzip "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii"
fi

# Compress the coregistration output
gzip "/scratch/hb-EGRET-AAA/projects/EGRET+/sub-${subj}/ses-${ses}/anat/sub-${subj}_ses-${ses}_acq-spacecorp2iso_run-1_T2w.nii"