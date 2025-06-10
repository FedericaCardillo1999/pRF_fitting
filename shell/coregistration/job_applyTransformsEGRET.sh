#!/bin/sh
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB

# Load modules
module load AFNI
module load ANTs
module load FSL

subject=sub-$1
task=$2

nruns=6
new_res=1.0
denoising='nordic'

OLDPWD=${PWD}
PROJ_DIR=/scratch/hb-EGRET-AAA/projects/EGRET+
# PROJ_DIR=/scratch/hb-EGRET-AAA/projects/OVGU

# Always use anatomical from ses-01
ANAT_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-01/anat
T1w=${ANAT_DIR}/${subject}_ses-01_acq-MPRAGE_T1w.nii.gz
inplane_input=${PROJ_DIR}/${subject}/ses-02/anat/${subject}_ses-02_acq-fl2dtrainplane_run-2_T1w.nii.gz
inplane_output=${ANAT_DIR}/inplane_brain.nii.gz
fixed_image=${ANAT_DIR}/T1w_brain.nii.gz
mask_image=${ANAT_DIR}/T1w_brain_mask.nii.gz
output_prefix=${ANAT_DIR}/
transform_file="${output_prefix}0GenericAffine.mat"

# Session
for s in 02 01; do
    CHECK_FILE=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${s}/func/${subject}_ses-${s}_task-${task}_run-1_bold.nii.gz
    if [ -f "$CHECK_FILE" ]; then
        session=$s
        echo "Found task data in ses-${session}"
        break
    fi
done

if [ -z "$session" ]; then
    exit 1
fi

UP_DIR=$PROJ_DIR/derivatives/upsampling/${subject}/ses-${session}/func/${denoising}
NII_DIR=$PROJ_DIR/derivatives/coreg/${subject}/ses-${session}/func
COREG_DIR=${PROJ_DIR}/derivatives/coreg/${subject}/ses-${session}
FUNC_DIR=$COREG_DIR/func

# Upsample BOLDREF
filename=${subject}_ses-${session}_task-${task}_run-1_boldref
if [[ ! -f ${NII_DIR}/${filename}.nii.gz ]]; then
    cp ${NII_DIR}/${filename}.nii.gz ${NII_DIR}/${filename}.nii.gz
else
    echo "Backup of original resolution ${filename} already exists"
fi
3dresample -dxyz ${new_res} ${new_res} ${new_res} -rmode Cubic -prefix ${NII_DIR}/${filename}_up.nii.gz -input ${NII_DIR}/${filename}.nii.gz -overwrite
cd ${OLDPWD}

# Preprocessing anat/inplane
cp "$inplane_input" "$ANAT_DIR/"
robustfov -i "$T1w" -r "${ANAT_DIR}/T1w.nii.gz"
bet "${ANAT_DIR}/T1w.nii.gz" "$fixed_image" -m -B -f 0.4
bet "$inplane_input" "$inplane_output" -m -B -f 0.4

# Run antsRegistration (only if transform file doesn't exist)
if [ ! -f "$transform_file" ]; then
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
    echo "Transform file: $transform_file"
fi

# Apply transform to BOLDREF
EPI_MEAN_UP=${NII_DIR}/${filename}_up.nii.gz
antsApplyTransforms --interpolation BSpline[5] -d 3 -i ${EPI_MEAN_UP} -r ${T1w} -o ${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-1_boldref_transformed.nii.gz -t ${transform_file}

# Apply transform to each run of BOLD
for run in $(seq "$nruns")
do
    EPI=${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
    if [ -f "$EPI" ]; then
        echo "Applying transforms to ${EPI}..."
        antsApplyTransforms --interpolation Linear -d 3 -e 3 -i ${EPI} -r ${T1w} -o ${FUNC_DIR}/${subject}_ses-${session}_task-${task}_run-${run}_bold_transformed.nii.gz -t ${transform_file} -v 1
    else
        echo "Run ${run} not found for ${subject}"
    fi
done
