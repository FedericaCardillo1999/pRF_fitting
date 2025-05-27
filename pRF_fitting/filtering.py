#!/usr/bin/env python
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
import os
import sys
from glob import glob
from scipy import signal

# Command: 
# python /home2/p315561/programs/cflaminar/pRF_fitting/filtering.py subject task

# Arguments 
subject = f"sub-{sys.argv[1]}"
task = sys.argv[2]

# Settings
filter = 1
depth_list = ['GM']
MAIN_PATH = '/scratch/hb-EGRET-AAA/projects/EGRET+/derivatives'

# --- Auto-detect session
session = None
for sess in ["ses-01", "ses-02"]:
    search_pattern = os.path.join(MAIN_PATH, resampling, subject, sess, "nordic", f"{subject}_{sess}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic_bold_GM.gii")
    if glob(search_pattern):
        session = sess
        break

if session is None:
    print(f"Error: Task '{task}' not found for {subject} in ses-01 or ses-02")
    sys.exit(1)

# --- Count runs
run_files = sorted(glob(os.path.join(MAIN_PATH, resampling, subject, session, "nordic", f"{subject}_{session}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic_bold_GM.gii")))
nruns = len(run_files)

# --- Process both denoising types
for denoising in ['nordic', 'nordic_sm4']:
    for depth in depth_list:
        proc_tc_RH = []
        proc_tc_LH = []

        for run in range(1, nruns + 1):
            path_L = f'{MAIN_PATH}/resampled/{subject}/{session}/{denoising}/{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-L_desc-{denoising}_bold_{depth}.gii'
            path_R = f'{MAIN_PATH}/resampled/{subject}/{session}/{denoising}/{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-R_desc-{denoising}_bold_{depth}.gii'

            if not (os.path.exists(path_L) and os.path.exists(path_R)):
                print(f"Run {run} missing files, skipping...")
                continue
                
            proc_tc_L = nib.load(path_L)
            proc_tc_R = nib.load(path_R)

            tc_L = proc_tc_L.agg_data().T
            tc_R = proc_tc_R.agg_data().T

            if task != 'RestingState':
                tc_L = tc_L[:136, :] if tc_L.shape[0] > 136 else tc_L
                tc_R = tc_R[:136, :] if tc_R.shape[0] > 136 else tc_R

            def normalize(tc):
                mean = np.nanmean(tc, axis=0)
                mean[mean == 0] = np.nan
                scale = 100 / mean
                scale = np.nan_to_num(scale, nan=0.0, posinf=0.0, neginf=0.0)
                tc_m = tc * scale[np.newaxis, :]
                return np.nan_to_num(tc_m, nan=0.0, posinf=0.0, neginf=0.0)

            tc_m_L = normalize(tc_L)
            tc_m_R = normalize(tc_R)

            tc_m_L -= np.median(tc_m_L[:5], axis=0)
            tc_m_R -= np.median(tc_m_R[:5], axis=0)

            if filter == 1:
                def highpass(tc):
                    TR = 1.5
                    fs = 1 / TR
                    nyquist = 0.5 * fs
                    mean = np.mean(tc, axis=0)
                    tc = signal.detrend(tc, axis=0) + mean
                    
                    if task == 'RestingState':
                        # Bandpass: 0.01–0.1 Hz using 4th-order Butterworth
                        lowcut = 0.01
                        highcut = 0.1
                        f_low = lowcut / nyquist
                        f_high = highcut / nyquist
                        sos = signal.butter(4, [f_low, f_high], btype='bandpass', output='sos')
                    else:
                        # Highpass only: > 0.006 Hz
                        lowcut = 0.006
                        f_low = lowcut / nyquist
                        sos = signal.butter(8, f_low, btype='highpass', output='sos')

                tc_m_L = highpass(tc_m_L)
                tc_m_R = highpass(tc_m_R)

            proc_tc_LH.append(tc_m_L)
            proc_tc_RH.append(tc_m_R)


        mean_proc_tc_LH = np.median(np.array(proc_tc_LH), axis=0)
        mean_proc_tc_RH = np.median(np.array(proc_tc_RH), axis=0)

        out_path = f'{MAIN_PATH}/pRFM/{subject}/{session}/{denoising}/'
        os.makedirs(out_path, exist_ok=True)
        np.save(f'{out_path}/{subject}_{session}_task-{task}_hemi-lh_desc-avg_bold_{depth}.npy', mean_proc_tc_LH)
        np.save(f'{out_path}/{subject}_{session}_task-{task}_hemi-rh_desc-avg_bold_{depth}.npy', mean_proc_tc_RH)
        
        psc_LR = np.hstack([mean_proc_tc_LH, mean_proc_tc_RH])
        np.save(f'{out_path}/{subject}_{session}_task-{task}_hemi-LR_desc-avg_bold_{depth}.npy', psc_LR)