#! /bin/sh
#$ -N antsTransform
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

# Load modules
module load afni
module load ANTs

# Usage: source upsampling.sh sub-xxx
# Upsamples Nifti files

subject=sub-$1
session=1

OLDPWD=${PWD}
PROJ_DIR=/data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp
cd $PROJ_DIR

COREG_DIR=$PROJ_DIR/derivatives/pymp2rage/${subject}/ses-${session}

T1w=${COREG_DIR}/${subject}_ses-${session}_acq-MP2RAGE_T1w.nii.gz
T2w=${COREG_DIR}/${subject}_ses-${session}_acq-3DTSE_T2w.nii.gz

#Transform T2w

antsApplyTransforms --interpolation linear -d 3 -i ${T2w} -r ${T1w} -o ${COREG_DIR}/${subject}_ses-${session}_acq-3DTSE_T2wcoreg.nii.gz -t ${COREG_DIR}/T2wtoT1w.txt --verbose
cp ${COREG_DIR}/${subject}_ses-${session}_acq-3DTSE_T2wcoreg.nii.gz ${PROJ_DIR}/${subject}/ses-${session}/anat/${subject}_ses-${session}_acq-3DTSE_T2w.nii.gz
