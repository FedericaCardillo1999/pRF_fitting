import numpy as np
import subprocess
import os

# Set up the main variables
subject='sub-48' 
space='fsnative'
project='PROJECT_EGRET-AAA'
import re
#MAIN_PATH='/Users/federicacardillo/Desktop/EGRET-AAA/July/preprocessing/denoising'
MAIN_PATH=f'/Volumes/FedericaCardillo/pre-processing/projects/{project}/derivatives'
# MAIN_PATH = '/Volumes/FedericaCardillo'
rois = np.array([['V1', 'V2', 'V3', 'LO', 'V4'], [1, 2, 3, 4, 5]])
fs_dirPATH=f'{MAIN_PATH}/freesurfer'

all_subjects = [d for d in os.listdir(fs_dirPATH) if re.match(r'sub-\d+', d)]

for subject in all_subjects:
    sub_num = int(subject.split('-')[1])
    if 2 <= sub_num <= 7 or 9 <= sub_num <= 12 or 14 <= sub_num <= 46 :
        continue  # Skip sub-02 to sub-08, sub-13, and sub-21 to sub-46


    for hemi in {'lh', 'rh'}:
        for roi in range(rois[0].__len__()):
            fname=f'{fs_dirPATH}/{subject}/label/{hemi}.manual_{rois[0][roi]}.label'
            outname=f'{fs_dirPATH}/{subject}/label/{hemi}.manual{rois[0][roi]}edit.label'
            with open(fname, 'r') as f_in, open(outname, 'w') as f_out:
                counter=0
                for line in f_in:
                    counter=counter+1
                    if counter>2:
                        output_line = line
                        editline=output_line.split(' ')
                        editline[7] =f'{rois[1][roi]}\n'
                        output_line=' '.join(editline)
                    else:
                        output_line = line
                    f_out.write(output_line)
                    print(output_line)

    # Navigate inside the Freesurfer subject's directory 
    label_dir = os.path.join(fs_dirPATH, subject, 'label')
    os.chdir(label_dir)
    print(f"Changed directory to: {label_dir}")

    rh_command = "mri_mergelabels -i rh.manualV1edit.label -i rh.manualV2edit.label -i rh.manualV3edit.label -i rh.manualLOedit.label -i rh.manualV4edit.label -o rh.manualdelin.label"
    lh_command = "mri_mergelabels -i lh.manualV1edit.label -i lh.manualV2edit.label -i lh.manualV3edit.label -i lh.manualLOedit.label -i lh.manualV4edit.label -o lh.manualdelin.label"
    subprocess.run(rh_command, shell=True, check=True)
    subprocess.run(lh_command, shell=True, check=True)

    print(f"Run successfully for {subject}")