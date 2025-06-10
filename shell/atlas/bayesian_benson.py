#!/usr/bin/env python
# coding: utf-8

import sys
import os
import nibabel as nib
import numpy as np
from nibabel.freesurfer.io import read_morph_data

subject = f'sub-{sys.argv[1:][0]}'
print(subject)
denoising = sys.argv[2:][0]
print(denoising)

# Set the freesurfer directory
freesurfer_dir = f'/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives/freesurfer/{subject}/surf'

# File names
files = [f'lh.masked_pol_{denoising}', f'rh.masked_pol_{denoising}', f'lh.masked_ecc_{denoising}', f'rh.masked_ecc_{denoising}', 
         f'lh.masked_r2_{denoising}', f'rh.masked_r2_{denoising}', f'lh.masked_radius_{denoising}', f'rh.masked_radius_{denoising}']
new_names = ['lh.all-angle', 'rh.all-angle', 'lh.all-eccen', 'rh.all-eccen',
             'lh.all-vexpl', 'rh.all-vexpl', 'lh.all-sigma', 'rh.all-sigma']

# Process each file
for old_file, new_file in zip(files, new_names):
    file_path = os.path.join(freesurfer_dir, old_file)
    # Read the data
    data = read_morph_data(file_path)
        
    # Create the new .mgz file
    mgz_file = os.path.join(freesurfer_dir, new_file + '.mgz')
    nib.save(nib.MGHImage(data.astype(np.float32), affine=np.eye(4)), mgz_file)

# Freesurfer dir 
os.chdir(f'{freesurfer_dir}')

# Run the neuropythy command for the Bayesian Benson Atlas
neuropythy_command = f"""
python -m neuropythy register_retinotopy {subject} --verbose \
       --surf-outdir=. \
       --surf-format="mgz" \
       --no-volume-export \
       --lh-angle=lh.all-angle.mgz \
       --lh-eccen=lh.all-eccen.mgz \
       --lh-weight=lh.all-vexpl.mgz \
       --lh-radius=lh.all-sigma.mgz \
       --rh-angle=rh.all-angle.mgz \
       --rh-eccen=rh.all-eccen.mgz \
       --rh-weight=rh.all-vexpl.mgz \
       --rh-radius=rh.all-sigma.mgz
"""
os.system(neuropythy_command)

# Labels dir
labels_dir = os.path.join(freesurfer_dir, 'labels')
os.makedirs(labels_dir, exist_ok=True)

# Define the files to convert to labels
inferred_files = [
    'lh.inferred_eccen.mgz', 'rh.inferred_eccen.mgz',
    'lh.inferred_angle.mgz', 'rh.inferred_angle.mgz',
    'lh.inferred_varea.mgz', 'rh.inferred_varea.mgz',
    'lh.inferred_sigma.mgz', 'rh.inferred_sigma.mgz']

# Convert the  files to labels
for inferred_file in inferred_files:
    hemi, measure = inferred_file.split('.')[0], inferred_file.split('.')[1]
    label_file = os.path.join(labels_dir, f'{hemi}.{measure}.label')
    mri_cor2label_command = f"mri_cor2label --i {inferred_file} --id 1 --l {label_file}"

    os.system(mri_cor2label_command)
