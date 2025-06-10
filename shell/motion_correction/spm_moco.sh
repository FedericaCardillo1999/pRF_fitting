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

PROJ_DIR=/scratch/hb-EGRET-AAA/projects/OVGU
subject=sub-$1

task=$2

SPM_DIR=${PROJ_DIR}/derivatives/spm
INPUT_DIR=${PROJ_DIR}
DERIVATIVES=${PROJ_DIR}/derivatives

# Get the session and number of runs
session=""
nruns=0
for ses in 01 02; do
  func_dir=${INPUT_DIR}/${subject}/ses-${ses}/func
  if [ -d "$func_dir" ]; then
    run_files=$(find "$func_dir" -maxdepth 1 -type f -name "${subject}_ses-${ses}_task-${task}_run-*_bold.nii.gz")
    count=$(echo "$run_files" | grep -E "/${subject}_ses-${ses}_task-${task}_run-[0-9]+_bold.nii.gz" | wc -l)
    if [ "$count" -gt 0 ]; then
      session=$ses
      nruns=$count
      echo "Found $nruns run(s) for task ${task} in ses-${session}"
      break
    fi
  fi
done

NoMoCo_DIR=${SPM_DIR}/${subject}/ses-${session}/no_moco
OUT_DIR=${SPM_DIR}/${subject}/ses-${session}/func

mkdir -p $NoMoCo_DIR
mkdir -p $OUT_DIR

echo "Copying functional files..."
for run in $(seq "$nruns"); do
    cp ${INPUT_DIR}/${subject}/ses-${session}/func/${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz ${NoMoCo_DIR}
done

cd ${PATH_HOME}/programs/cflaminar/shell/motion_correction
echo "Running spmMoCo on project ${PROJ_DIR}, ${subject}, ses-${session}, task-${task}, with ${nruns} runs"

# Launch appropriate MATLAB script
case "$nruns" in
    2)
        if [[ "$task" == "RET" || "$task" == "RET2" ]]; then
            $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_2runs('OVGU', '${subject}', '${session}')"
        elif [[ "$task" == "RestingState" ]]; then
            $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_2runRestingState('OVGU', '${subject}', '${session}')"
        else
            echo "Task not supported for 2 runs: $task"
            exit 1
        fi
        ;;
    3)
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_3runs('OVGU', '${subject}', '${session}')"
        ;;
    4)
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_4runs('OVGU', '${subject}', '${session}')"
        ;;
    5)
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_5runs('OVGU', '${subject}', '${session}')"
        ;;
    6)
        $MATLAB_BIN -nodesktop -nodisplay -nosplash -r "main_spmmoco_6runs('OVGU', '${subject}', '${session}')"
        ;;
        
esac

# Check for MoCo output
if ! ls ${OUT_DIR}/meansub-${1}_ses-${session}_task-${task}_run-1_bold.nii 1> /dev/null 2>&1; then
    echo "SPM MoCo output not found. Exiting."
    exit 1
fi

cd ${OUT_DIR}
rm -r sub*

for run in $(seq "$nruns"); do
    gzip -c r${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold.nii > ${subject}_ses-${session}_task-${task}_run-${run}_desc-preproc_bold.nii.gz
    gzip -c r${subject}_ses-${session}_task-${task}_run-${run}_bold.nii > ${subject}_ses-${session}_task-${task}_run-${run}_bold.nii.gz
done

gzip -c mean${subject}_ses-${session}_task-${task}_run-1_desc-preproc_bold.nii > ${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
gzip -c mean${subject}_ses-${session}_task-${task}_run-1_bold.nii > ${subject}_ses-${session}_task-${task}_run-1_boldref.nii.gz
rm -r *.nii

mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-${session}/func
cp ${DERIVATIVES}/spm/${subject}/ses-${session}/func/*.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-${session}/func/
mkdir -p ${DERIVATIVES}/coreg/${subject}/ses-01/anat
cp ${INPUT_DIR}/derivatives/denoised/${subject}/ses-01/*T1w.nii.gz ${DERIVATIVES}/coreg/${subject}/ses-01/anat/

echo "Finished."
