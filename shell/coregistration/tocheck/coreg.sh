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

subject=sub-47
session=01

OLDPWD=${PWD}
PROJ_DIR=/Volumes/FedericaCardillo/pre-processing/projects/PROJECT_EGRET-AAA
cd "$PROJ_DIR"

COREG_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}
FUNC_DIR=${COREG_DIR}/func
T1w=${PROJ_DIR}/derivatives/coreg/${subject}/ses-01/anat/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz

RET_boldref=${FUNC_DIR}/${subject}_ses-${session}_task-RET_run-1_boldref.nii.gz
RET2_boldref=${FUNC_DIR}/${subject}_ses-${session}_task-RET2_run-1_boldref.nii.gz
REST_boldref=${FUNC_DIR}/${subject}_ses-${session}_task-RestingState_run-1_boldref.nii.gz

RET_boldref_transformed=${FUNC_DIR}/${subject}_ses-${session}_task-RET_run-1_boldref_transformed.nii.gz
RET2_boldref_transformed=${FUNC_DIR}/${subject}_ses-${session}_task-RET2_run-1_boldref_transformed.nii.gz
REST_boldref_transformed=${FUNC_DIR}/${subject}_ses-${session}_task-RestingState_run-1_boldref_transformed.nii.gz

# === Step 1: Align RET boldref to T1w ===
echo "Aligning RET boldref to T1w..."
antsApplyTransforms \
    -d 3 \
    -i "$RET_boldref" \
    -r "$T1w" \
    -o "$RET_boldref_transformed" \
    -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/anat/init_coreg.txt

# === Step 2: Align RET2 boldref to RET boldref transformed ===
echo "Registering RET2 boldref to RET boldref transformed..."
antsRegistrationSyNQuick.sh \
    -d 3 \
    -f "$RET_boldref_transformed" \
    -m "$RET2_boldref" \
    -o ${FUNC_DIR}/ret2_to_retAligned_

antsApplyTransforms \
    -d 3 \
    -i "$RET2_boldref" \
    -r "$RET_boldref_transformed" \
    -o "$RET2_boldref_transformed" \
    -t ${FUNC_DIR}/ret2_to_retAligned_0GenericAffine.mat

# === Step 3: Align RestingState boldref to T1w ===
echo "Aligning RestingState boldref to T1w..."
antsApplyTransforms \
    -d 3 \
    -i "$REST_boldref" \
    -r "$T1w" \
    -o "$REST_boldref_transformed" \
    -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/anat/init_coreg.txt

# === Apply transforms to functional runs ===
for task in RET RET2 RestingState; do
    echo "Processing $task functional runs..."

    run_files=($(find ${FUNC_DIR} -maxdepth 1 -type f -name "${subject}_ses-${session}_task-${task}_run-*_bold.nii.gz" ! -name "*_transformed.nii.gz"))
    if [ ! -e "${run_files[0]}" ]; then
        echo "No runs found for task ${task}. Skipping..."
        continue
    fi

    for EPI in "${run_files[@]}"; do
        run=$(basename "$EPI" | grep -o '_run-[0-9]\+' | cut -d'-' -f2)
        OUT=${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz
        echo "Transforming $EPI..."

        if [ "$task" = "RET2" ]; then
            antsApplyTransforms \
                --interpolation Linear \
                -d 3 \
                -e 3 \
                -i "$EPI" \
                -r "$RET2_boldref" \
                -o "$OUT" \
                -t ${FUNC_DIR}/ret2_to_retAligned_0GenericAffine.mat \
                -v 1
        else
            boldref_var=${task^^}_boldref  # expands to RET_boldref or REST_boldref
            antsApplyTransforms \
                --interpolation Linear \
                -d 3 \
                -e 3 \
                -i "$EPI" \
                -r "${!boldref_var}" \
                -o "$OUT" \
                -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/anat/init_coreg.txt \
                -v 1
        fi

        cp "$OUT" ${PROJ_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
    done
done

# === ITK-SNAP view ===
echo "Preparing to launch ITK-SNAP for visual inspection..."

anat_image=$T1w
ret_func=$(find ${PROJ_DIR}/${subject}/ses-${session}/func -name "${subject}_ses-${session}_task-RET_run-*_bold.nii.gz" | head -n 1)
ret2_func=$(find ${PROJ_DIR}/${subject}/ses-${session}/func -name "${subject}_ses-${session}_task-RET2_run-*_bold.nii.gz" | head -n 1)
rest_func=$(find ${PROJ_DIR}/${subject}/ses-${session}/func -name "${subject}_ses-${session}_task-RestingState_run-*_bold.nii.gz" | head -n 1)

if [ -f "$anat_image" ] && [ -f "$ret_func" ] && [ -f "$ret2_func" ] && [ -f "$rest_func" ]; then
    echo "Launching ITK-SNAP with:"
    echo "Main image: $anat_image"
    echo "Overlay 1:  $ret_func"
    echo "Overlay 2:  $ret2_func"
    echo "Overlay 3:  $rest_func"

    ITK-SNAP -g "$anat_image" -o "$ret_func" "$ret2_func" "$rest_func"
else
    echo "ERROR: Could not find all required images to open ITK-SNAP."
    echo "T1w: $anat_image"
    echo "RET: $ret_func"
    echo "RET2: $ret2_func"
    echo "RestingState: $rest_func"
fi