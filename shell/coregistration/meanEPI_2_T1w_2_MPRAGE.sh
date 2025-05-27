#!/bin/bash
#SBATCH --time=00:30:00
#SBATCH --nodes=1
#SBATCH --cpus-per-task=25
#SBATCH --mem=5GB

#!/bin/bash
module load FSL/6.0.5.1-foss-2021a
module load NiBabel/3.2.1-foss-2021a
module load ANTs/2.5.0-foss-2022b
module load SciPy-bundle/2021.05-foss-2021a

# Set subject and session from command-line arguments
subj="sub-$1"

# Define base directory, derivative directory, and paths
base_directory="/scratch/hb-EGRET-AAA/projects/EGRET+/${subj}"
coreg_directory="/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/coreg/${subj}"

# Paths for input images (note that the MPRAGE is in the base_directory, but everything else goes to the derivative directory)
input_image="${coreg_directory}/ses-01/anat/${subj}_ses-01_acq-MPRAGE_T1w.nii.gz"


output_image="${coreg_directory}/ses-01/anat/T1w.nii.gz"
inplane_input="${base_directory}/ses-02/anat/${subj}_ses-02_acq-fl2dtrainplane_run-2_T1w.nii.gz"
inplane_output="${coreg_directory}/ses-01/anat/inplane_brain.nii.gz"
fixed_image="${coreg_directory}/ses-01/anat/T1w_brain.nii.gz"
mask_image="${coreg_directory}/ses-01/anat/T1w_brain_mask.nii.gz"
epi_image="${coreg_directory}/ses-02/func/${subj}_ses-02_task-RET_run-1_boldref.nii.gz"
output_prefix="${coreg_directory}/ses-01/anat/"
transformed_epi_image="${output_prefix}/epi2t1.nii.gz"
transform_file="${output_prefix}0GenericAffine.mat"


# Copy inplane image to derivatives directory to avoid modifying the original subject directory
cp "$inplane_input" "${coreg_directory}/ses-01/anat/"

# Extract neck tissue from MPRAGE using robustfov
robustfov -i "$input_image" -r "$output_image"

# Brain extraction using BET for T1-weighted and inplane images
bet_commands=(
    "bet ${output_image} ${fixed_image} -m -B -f 0.4"
    "bet ${inplane_input} ${inplane_output} -m -B -f 0.4"
)

for cmd in "${bet_commands[@]}"; do
    eval "$cmd"
done

# Register inplane to T1w with mask using antsRegistration
registration_command=(
    "antsRegistration --verbose 1"
    "--dimensionality 3 --float 0 --interpolation Linear"
    "--use-histogram-matching 0 --winsorize-image-intensities [0.005,0.995]"
    "--output [${output_prefix},${output_prefix}Warped.nii.gz,${output_prefix}InverseWarped.nii.gz]"
    "--initial-moving-transform [${fixed_image},${inplane_output},1]"                                                   ####### init_coreg.txt
    "--transform translation[0.1]"
    "--metric MI[${fixed_image},${inplane_output},1,32,Random,0.25]"
    "--convergence [50,1e-6,10] --shrink-factors 1 --smoothing-sigmas 0vox"
    "--masks [${mask_image},NULL]"
    "--transform Rigid[0.1]"
    "--metric MI[${fixed_image},${inplane_output},1,32,Random,0.25]"
    "--convergence [500x250x50,1e-6,10] --shrink-factors 2x2x1 --smoothing-sigmas 2x1x0vox"
    "--masks [${mask_image},NULL]"
)

# Run antsRegistration command
eval "${registration_command[@]}"

# Apply transformation to BOLD image
if [ -f "$transform_file" ]; then
    transform_command="antsApplyTransforms -n BSpline[5] -d 3 -i $epi_image -r $epi_image -t ${transform_file} -o ${transformed_epi_image}"         ####### init_coreg.txt check 
    eval "$transform_command"
else
    echo "Transform file does not exist: $transform_file. Please check the antsRegistration step."
fi
