#!/bin/sh

#$ -N antsTransform
#$ -S /bin/sh
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB

# Load modules if needed
#module load AFNI
#module load ANTs

# Subject/task info
subject=sub-47
session=01
task=RET
nruns=4

OLDPWD=${PWD}
PROJ_DIR=/Volumes/FedericaCardillo/pre-processing/projects/EGRET+
cd $PROJ_DIR

COREG_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}
FUNC_DIR=${COREG_DIR}/func
ANAT_DIR=${COREG_DIR}/anat

mkdir -p ${FUNC_DIR}
mkdir -p ${ANAT_DIR}

# Input paths
T1w=${PROJ_DIR}/derivatives/coreg/${subject}/ses-01/anat/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz
BOLDREF=${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
TRANSFORM_PATH=${COREG_DIR}/anat/init_coreg.txt

# Output reference: T1w resampled to functional resolution/FOV
T1w_like_func=${ANAT_DIR}/${subject}_ses-${session}_T1w_like_func.nii.gz

# ===============================
# STEP 1: Create T1w resampled into functional grid
# ===============================
echo "📏 Resampling T1w to functional space (same resolution & FOV)..."
antsApplyTransforms \
  -d 3 \
  -i ${T1w} \
  -r ${BOLDREF} \
  -o ${T1w_like_func} \
  -n Linear \
  -t identity

# ===============================
# STEP 2: Transform boldref (sanity check)
# ===============================
echo "✅ Transforming boldref to check alignment..."
antsApplyTransforms \
  --interpolation BSpline[5] \
  -d 3 \
  -i ${BOLDREF} \
  -r ${T1w_like_func} \
  -o ${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref_transformed.nii.gz \
  -t ${TRANSFORM_PATH}

# ===============================
# STEP 3: Apply transform to each BOLD run
# ===============================
for run in $(seq "$nruns")
do
  EPI=${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
  EPI_OUT=${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz

  echo "🚀 Transforming BOLD run ${run} into T1w space..."
  antsApplyTransforms \
    --interpolation Linear \
    -d 3 -e 3 \
    -i ${EPI} \
    -r ${T1w_like_func} \
    -o ${EPI_OUT} \
    -t ${TRANSFORM_PATH} \
    -v 1

  cp ${EPI_OUT} ${PROJ_DIR}/${subject}/ses-${session}/func/
done

echo "🎉 All BOLD runs transformed successfully into T1w space with functional resolution — no cropping expected."