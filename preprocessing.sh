# Denoising anatomical 
# master -m 08 -s 01 -n 01 --ow

# Denoising functional 
# master -m 10 -s 01 -n 01 --ow

# Motion Correction 
# source /home2/p315561/programs/cflaminar/shell/motion_correction/spm_moco.sh subject task nruns

# Coregistration 
source /home2/p315561/programs/cflaminar/shell/coregistration/coreg_T2.sh subj ses



# Freesurfer 
# master -m 14 -s 01 -n 01 --ow

# Pycortex

# Atlas 
# python /home2/p315561/programs/cflaminar/shell/atlas/bayesian_benson.py subject denoising
# source /home2/p315561/programs/cflaminar/shell/atlas/standard_benson.sh subject

# Resampling 
# source /home2/p315561/programs/cflaminar/shell/resampling/resampling.sh subject task

# Filtering
# python /home2/p315561/programs/cflaminar/pRF_fitting/filtering.py subject task

# pRF fitting 
# python /home2/p315561/programs/cflaminar/pRF_fitting/main_PRFs.py.py subject denoising depth atlas ncores task

# Visual Field Maps 
# python /home2/p315561/programs/cflaminar/pRF_fitting/visual_field_maps.py subject task