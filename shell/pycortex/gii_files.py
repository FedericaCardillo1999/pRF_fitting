import os
import sys
import shutil
import subprocess

# Parameters
subject_id = "48"

subject = "sub-48"
suffix = "ses-01_acq-MPRAGE"
freesurfer_dir = f"/Volumes/FedericaCardillo/pre-processing/projects/PROJECT_EGRET-AAA/derivatives/freesurfer/{subject}"
derivatives_dir = os.getenv("DERIVATIVES") or "/Volumes/FedericaCardillo/pre-processing/projects/PROJECT_EGRET-AAA/derivatives"

# Output paths
anat_dir = os.path.join(derivatives_dir, "fmriprep", subject, "ses-01", "anat")
temp_dir = os.path.join(derivatives_dir, "fmriprep", subject, "anat")
os.makedirs(anat_dir, exist_ok=True)
os.makedirs(temp_dir, exist_ok=True)

def convert_mgz_to_nii(mgz_path, out_path):
    subprocess.run(["mri_convert", mgz_path, out_path], check=True)

def convert_surf_to_gii(surf_path, out_path):
    subprocess.run(["mris_convert", surf_path, out_path], check=True)

import nibabel as nib
import numpy as np

def generate_midthickness_in_python(hemi):
    print(f"\nGenerating midthickness for {hemi} using Python...")

    white_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{'L' if hemi == 'lh' else 'R'}_smoothwm.surf.gii")
    pial_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{'L' if hemi == 'lh' else 'R'}_pial.surf.gii")
    midthick_path = os.path.join(temp_dir, f"{subject}_{suffix}_hemi-{'L' if hemi == 'lh' else 'R'}_midthickness.surf.gii")

    # Load surfaces
    white = nib.load(white_path)
    pial = nib.load(pial_path)

    white_coords = white.darrays[0].data
    pial_coords = pial.darrays[0].data
    faces = white.darrays[1].data

    # Compute average
    mid_coords = (white_coords + pial_coords) / 2.0

    # Save new GIFTI surface
    midthick_gii = nib.gifti.GiftiImage(darrays=[
        nib.gifti.GiftiDataArray(mid_coords, intent='NIFTI_INTENT_POINTSET'),
        nib.gifti.GiftiDataArray(faces.astype(np.int32), intent='NIFTI_INTENT_TRIANGLE')
    ])
    nib.save(midthick_gii, midthick_path)
    print(f"Saved: {midthick_path}")

    return midthick_path



# Step 1: Convert T1 and aseg
t1_out = os.path.join(temp_dir, f"{subject}_{suffix}_desc-preproc_T1w.nii.gz")
aseg_out = os.path.join(temp_dir, f"{subject}_{suffix}_desc-aseg_dseg.nii.gz")
convert_mgz_to_nii(os.path.join(freesurfer_dir, "mri", "T1.mgz"), t1_out)
convert_mgz_to_nii(os.path.join(freesurfer_dir, "mri", "aseg.mgz"), aseg_out)

# Step 2: Convert surfaces
hemis = ['lh', 'rh']
surf_types = {
    'inflated': 'inflated',
    'pial': 'pial',
    'smoothwm': 'white',
    'midthickness': 'mid'  # generated below
}

for hemi in hemis:
    for surf_name, fs_file in surf_types.items():
        if surf_name == 'midthickness':
            mid_path = generate_midthickness_in_python(hemi)
            fs_path = mid_path

        else:
            fs_path = os.path.join(freesurfer_dir, "surf", f"{hemi}.{fs_file}")
        out_name = f"{subject}_{suffix}_hemi-{'L' if hemi == 'lh' else 'R'}_{surf_name}.surf.gii"
        out_path = os.path.join(temp_dir, out_name)
        convert_surf_to_gii(fs_path, out_path)

# Step 3: Rename and move files
file_list = [f'{subject}_{suffix}_desc-preproc_T1w.nii.gz', f'{subject}_{suffix}_desc-aseg_dseg.nii.gz', 
             f'{subject}_{suffix}_hemi-R_inflated.surf.gii', f'{subject}_{suffix}_hemi-R_midthickness.surf.gii',
             f'{subject}_{suffix}_hemi-R_pial.surf.gii', f'{subject}_{suffix}_hemi-R_smoothwm.surf.gii',
             f'{subject}_{suffix}_hemi-L_inflated.surf.gii', f'{subject}_{suffix}_hemi-L_midthickness.surf.gii',
             f'{subject}_{suffix}_hemi-L_pial.surf.gii', f'{subject}_{suffix}_hemi-L_smoothwm.surf.gii']

new_file_list = [f'{subject}_desc-preproc_T1w.nii.gz', f'{subject}_desc-aseg_dseg.nii.gz', 
                 f'{subject}_hemi-R_inflated.surf.gii', f'{subject}_hemi-R_midthickness.surf.gii',
                 f'{subject}_hemi-R_pial.surf.gii', f'{subject}_hemi-R_smoothwm.surf.gii',
                 f'{subject}_hemi-L_inflated.surf.gii', f'{subject}_hemi-L_midthickness.surf.gii',
                 f'{subject}_hemi-L_pial.surf.gii', f'{subject}_hemi-L_smoothwm.surf.gii']

for old, new in zip(file_list, new_file_list):
    old_path = os.path.join(temp_dir, old)
    new_path = os.path.join(temp_dir, new)
    try:
        os.rename(old_path, new_path)
        print(f"Renamed {old} -> {new}")
        shutil.copyfile(new_path, os.path.join(anat_dir, new))
    except FileNotFoundError:
        print(f"File not found: {old_path}")
    except FileExistsError:
        print(f"File already exists: {new_path}")

# Step 4: Pycortex import
import cortex
from cortex import fmriprep

fmriprep.import_subj(subject_id, derivatives_dir)

# Step 5: FreeSurfer import into cortex
cortex.freesurfer.import_subj(subject, freesurfer_subject_dir=os.path.dirname(freesurfer_dir))

# Optional fix for fiducial
pycortex_db = cortex.database.default_filestore
try:
    shutil.copyfile(f'{pycortex_db}/{subject_id}/surfaces/fiducial_lh.gii', f'{pycortex_db}/{subject}/surfaces/fiducial_lh.gii')
    shutil.copyfile(f'{pycortex_db}/{subject_id}/surfaces/fiducial_rh.gii', f'{pycortex_db}/{subject}/surfaces/fiducial_rh.gii')
except FileNotFoundError as e:
    print(f"Surface file copy failed: {e}")
