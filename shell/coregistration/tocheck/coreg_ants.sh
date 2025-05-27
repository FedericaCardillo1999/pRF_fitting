#!/bin/bash

#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB

# Load required modules
module load FSL/6.0.5.1-foss-2021a
module load ANTs/2.5.0-foss-2022b

# ===== Variables =====
subject=sub-23 # 08 
session=02

OLDPWD=${PWD}
PROJ_DIR=/Volumes/FedericaCardillo/pre-processing/projects/EGRET+
cd "$PROJ_DIR"

COREG_DIR=${PROJ_DIR}/zderivatives/coreg/${subject}/ses-${session}
FUNC_DIR=${COREG_DIR}/func
ANAT_DIR=${PROJ_DIR}/zderivatives/coreg/${subject}/ses-01/anat

T1w=${ANAT_DIR}/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz
inplane_input=${PROJ_DIR}/${subject}/ses-02/anat/${subject}_ses-02_acq-fl2dtrainplane_run-2_T1w.nii.gz
inplane_output=${ANAT_DIR}/inplane_brain.nii.gz
fixed_image=${ANAT_DIR}/T1w_brain.nii.gz
mask_image=${ANAT_DIR}/T1w_brain_mask.nii.gz
output_prefix=${ANAT_DIR}/
transform_file="${output_prefix}0GenericAffine.mat"

RET_boldref=${FUNC_DIR}/${subject}_ses-${session}_task-RET_run-1_boldref.nii.gz
RET2_boldref=${FUNC_DIR}/${subject}_ses-${session}_task-RET2_run-1_boldref.nii.gz
RET_boldref_transformed=${FUNC_DIR}/${subject}_ses-${session}_task-RET_run-1_boldref_transformed.nii.gz
RET2_boldref_transformed=${FUNC_DIR}/${subject}_ses-${session}_task-RET2_run-1_boldref_transformed.nii.gz

# ===== Step 0: Create transform if missing =====
if [ -f "$transform_file" ]; then
    echo "Transform file not found, creating it using antsRegistration..."

    cp "$inplane_input" "$ANAT_DIR/"
    robustfov -i "$T1w" -r "${ANAT_DIR}/T1w.nii.gz"

    bet "${ANAT_DIR}/T1w.nii.gz" "$fixed_image" -m -B -f 0.4
    bet "$inplane_input" "$inplane_output" -m -B -f 0.4

    antsRegistration --verbose 1 \
        --dimensionality 3 --float 0 --interpolation Linear \
        --use-histogram-matching 0 --winsorize-image-intensities [0.005,0.995] \
        --output ["${output_prefix}","${output_prefix}Warped.nii.gz","${output_prefix}InverseWarped.nii.gz"] \
        --initial-moving-transform ["$fixed_image","$inplane_output",1] \
        --transform translation[0.1] \
        --metric MI["$fixed_image","$inplane_output",1,32,Random,0.25] \
        --convergence [50,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0vox \
        --masks ["$mask_image",NULL] \
        --transform Rigid[0.1] \
        --metric MI["$fixed_image","$inplane_output",1,32,Random,0.25] \
        --convergence [500x250x50,1e-6,10] --shrink-factors 2x2x1 --smoothing-sigmas 2x1x0vox \
        --masks ["$mask_image",NULL]
else
    echo "Transform file already exists: $transform_file"
fi

# ===== Step 1: RET boldref to T1w =====
echo "Aligning RET boldref to T1w..."
antsApplyTransforms \
    -d 3 \
    -i "$RET_boldref" \
    -r "$T1w" \
    -o "$RET_boldref_transformed" \
    -t "$transform_file"

# Use init_coreg.txt (manual override option)
#antsApplyTransforms \
#     -d 3 \
#     -i "$RET_boldref" \
#     -r "$T1w" \
#     -o "$RET_boldref_transformed" \
#     -t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/anat/init_coreg.txt

# ===== Step 2: RET2 boldref to RET boldref transformed =====
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

# ===== Step 3: Apply transforms to all runs =====
for task in RET RET2; do
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
            antsApplyTransforms \
                --interpolation Linear \
                -d 3 \
                -e 3 \
                -i "$EPI" \
                -r "$RET_boldref" \
                -o "$OUT" \
                -t "$transform_file" \
                -v 1

            # Uncomment this line to use init_coreg.txt manually
            #-t ${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}/anat/init_coreg.txt
        fi

        cp "$OUT" ${PROJ_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
    done
done

# ===== ITK-SNAP Visualization =====
anat_image=$T1w
ret_func=$(find ${PROJ_DIR}/${subject}/ses-${session}/func -name "${subject}_ses-${session}_task-RET_run-*_bold.nii.gz" | head -n 1)
ret2_func=$(find ${PROJ_DIR}/${subject}/ses-${session}/func -name "${subject}_ses-${session}_task-RET2_run-*_bold.nii.gz" | head -n 1)

if [ -f "$anat_image" ] && [ -f "$ret_func" ] && [ -f "$ret2_func" ]; then
    echo "Launching ITK-SNAP..."
    ITK-SNAP -g "$anat_image" -o "$ret_func" "$ret2_func"
else
    echo "ERROR: Could not find all required images for ITK-SNAP."
fi
