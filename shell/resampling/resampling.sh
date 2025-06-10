#!/bin/bash
#$ -N resampling_GM
#$ -S /bin/bash
#$ -j y
#$ -q long.q
#$ -o /data1/projects/dumoulinlab/Lab_members/Mayra/projects/CFLamUp/code/logs
#$ -u bittencourt

#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --mem=20GB 

# Usage: source script_name.sh [subject] [task] / E.g. qsub -V script_name.sh 001 ret

subject=sub-$1
task=$2
depth=1.0
a=0

PROJ_DIR=${DIR_DATA_HOME}
OUT_DIR=${PROJ_DIR}/derivatives/resampled

# Get session 
for sess in ses-01 ses-02; do
  FUNC_DIR=${PROJ_DIR}/${subject}/${sess}/func
  if [[ -d "$FUNC_DIR" ]]; then
    if compgen -G "${FUNC_DIR}/${subject}_${sess}_task-${task}_run-*_bold.nii.gz" > /dev/null; then
      session=${sess}
      break
    fi
  fi
done

# Count number of runs for the task (exact match, not partial)
nruns=$(ls ${PROJ_DIR}/${subject}/${session}/func/${subject}_${session}_task-${task}_run-*_bold.nii.gz 2>/dev/null | wc -l)

echo "Using $session with $nruns runs for task '$task'"

# Create output directory
if [[ ! -d $OUT_DIR ]]; then
  mkdir -p $OUT_DIR
else
  echo "$OUT_DIR folder already exists."
fi

for denoising in nordic nordic_sm4; do
  SOURCE_DIR=${PROJ_DIR}/${subject}/${session}/func

  if [[ ! -d $OUT_DIR/${subject}/${session}/${denoising} ]]; then
    mkdir -p $OUT_DIR/${subject}/${session}/${denoising}
  else
    echo "$OUT_DIR/${subject}/${session}/${denoising} folder already exists."
  fi

  for hemi in lh rh; do
    for run in $(seq "$nruns"); do
      if [[ ${denoising} == "nordic" ]]; then
        filename=${subject}_${session}_task-${task}_run-${run}_bold
        smoothing=0
      elif [[ ${denoising} == "nordic_sm4" ]]; then
        filename=${subject}_${session}_task-${task}_run-${run}_bold
        smoothing=4
      fi

      if [ "$hemi" == "lh" ]; then h=L; else h=R; fi;

      mri_vol2surf \
        --src ${SOURCE_DIR}/${filename}.nii.gz \
        --out $OUT_DIR/${subject}/${session}/${denoising}/${subject}_${session}_task-${task}_run-${run}_space-fsnative_hemi-${h}_desc-${denoising}_bold_GM.gii \
        --hemi ${hemi} \
        --out_type gii \
        --projfrac-avg ${a} ${depth} 0.1 \
        --interp "trilinear" \
        --regheader ${subject} \
        --surf-fwhm $smoothing \
        --cortex
    done
  done
done
