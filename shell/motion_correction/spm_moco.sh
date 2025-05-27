#! /bin/bash
#$ -N spmMoCo
#$ -S /bin/bash
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt
#$ -V
#SBATCH --job-name=spmMoCo
#SBATCH --time=2:00:00
#SBATCH --partition=regular
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1

MATLAB_BIN="/cvmfs/hpc.rug.nl/versions/2023.01/rocky8/x86_64/generic/software/MATLAB/2022b-r5/bin/matlab"

PROJ_DIR=/scratch/hb-EGRET-AAA/projects/EGRET+
subject=sub-$1
task=$2
nruns=$3

SPM_DIR=${PROJ_DIR}/derivatives/spm
INPUT_DIR=${PROJ_DIR}

# Check for session with matching task data
session=""
for ses in 01 02; do
  test_file=${INPUT_DIR}/${subject}/ses-${ses}/func/${subject}_ses-${ses}_task-${task}_run-1_bold.nii.gz
  if [[ -f $test_file ]]; then
    session=$ses
    echo "Found task ${task} in ses-${session}"
    break
  fi
done

if [[ -z $session ]]; then
  echo "Could not find task ${task} in ses-01 or ses-02 for ${subject}"
  exit 1
fi

NoMoCo_DIR=${SPM_DIR}/${subject}/ses-${session}/no_moco
OUT_DIR=${SPM_DIR}/${subject}/ses-${session}/func

# Prepare folders
mkdir -p $NoMoCo_DIR
mkdir -p $OUT_DIR

echo "Copying functional files..."
for run in $(seq "$nruns"); do
    cp ${INPUT_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz ${NoMoCo_DIR}
done

cd ${PATH_HOME}/programs/cflaminar/shell/motion_correction
echo "Running spmMoCo on project ${PROJ_DIR}, ${subject}, ses-${session}, task-${task}"

# Select correct MATLAB script based on task and number of runs
if [[ ${nruns} == "2" ]]; then
    if [[ "$task" == "RET" || "$task" == "RET2" ]]; then
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_2runs('${PROJ_DIR}', '$1', '${session}')"
    elif [[ "$task" == "RestingState" ]]; then
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_2runRestingState('EGRET+', '$1', '${session}')"
    else
        echo "Task not supported for 2 runs: $task"
        exit 1
    fi
elif [[ ${nruns} == "3" ]]; then
    $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_3runs('${PROJ_DIR}', '$1')"
elif [[ ${nruns} == "4" ]]; then
    $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_4runs('${PROJ_DIR}', '$1')"
elif [[ ${nruns} == "5" ]]; then
    $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_5runs('${PROJ_DIR}', '$1')"
elif [[ ${nruns} == "6" ]]; then
    $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_6runs('${PROJ_DIR}', '$1')"
else
    echo "Sorry, I can only process 2 to 6 runs."
    exit 1
fi

# Wait for MoCo to finish
until ls ${OUT_DIR}/meansub-${1}_ses-${session}_task-${task}_run-1_bold.nii 1> /dev/null 2>&1; do
    echo "Waiting for spm MoCo to finish..."
    sleep 1
done

echo "✅ SPM MoCo finished. Cleaning directory and compressing files..."
cd ${OUT_DIR}
rm -r sub*

for run in $(seq "$nruns"); do
    gzip -c r${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold.nii > ${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold.nii.gz
    gzip -c r${subject}_ses-${session}_task-${task}_run-${run}_bold.nii > ${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
done

gzip -c mean${subject}_ses-${session}_task-${task}_run-1_desc-preproc_bold.nii > ${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
gzip -c mean${subject}_ses-${session}_task-${task}_run-1_bold.nii > ${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
rm -r *.nii

echo "Preparing coreg folder for manual coregistration."
mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-${session}/func
cp ${DERIVATIVES}/spm/${subject}/ses-${session}/func/*.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-${session}/func/
mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-01/anat
cp ${INPUT_DIR}/derivatives/denoised/${subject}/ses-01/*T1w.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-01/anat/
echo "🎉 Finished."
