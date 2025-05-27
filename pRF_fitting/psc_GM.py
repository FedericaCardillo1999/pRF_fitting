#!/usr/bin/env python
# %%
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
import os
import sys
from glob import glob
from scipy import signal

# %%
# args: subject, task
subject = f'sub-{sys.argv[1]}'
task = sys.argv[2]
MAIN_PATH = os.getenv("DERIVATIVES")
resampling = 'resampled'
depth_list = ['GM']
filter = 1

# Automatically find session
session = None
for sess in ["ses-01", "ses-02"]:
    func_path = os.path.join(MAIN_PATH, resampling, subject, sess)
    pattern = os.path.join(func_path, "nordic", f"{subject}_{sess}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic_bold_GM.gii")
    if len(glob(pattern)) > 0:
        session = sess
        break

if session is None:
    print(f"Error: Task '{task}' not found in any session for subject {subject}")
    sys.exit(1)

# Count number of runs for the task (carefully match task name)
run_pattern = os.path.join(MAIN_PATH, resampling, subject, session, "nordic", f"{subject}_{session}_task-{task}_run-*_space-fsnative_hemi-L_desc-nordic_bold_GM.gii")
runs = sorted(glob(run_pattern))
nruns = len(runs)

if nruns == 0:
    print(f"No runs found for task '{task}' in {session} for subject {subject}")
    sys.exit(1)

print(f"Using {session} with {nruns} runs for task '{task}'")

# Loop over denoising strategies
for denoising in ['nordic', 'nordic_sm4']:
    for depth in depth_list:
        proc_tc = []
        for run in range(1, nruns + 1):
            path_L = f'{MAIN_PATH}/{resampling}/{subject}/{session}/{denoising}/{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-L_desc-{denoising}_bold_{depth}.gii'
            path_R = f'{MAIN_PATH}/{resampling}/{subject}/{session}/{denoising}/{subject}_{session}_task-{task}_run-{run}_space-fsnative_hemi-R_desc-{denoising}_bold_{depth}.gii'

            try:
                proc_tc_L = nib.load(path_L)
                proc_tc_R = nib.load(path_R)
            except FileNotFoundError:
                print(f"Run {run} missing for {denoising}, skipping...")
                continue

            tc = np.vstack([proc_tc_L.agg_data(), proc_tc_R.agg_data()]).T

            if task != 'RestingState' and tc.shape[0] > 136:
                tc = tc[:136, :]

            col_means = np.nanmean(tc, axis=0)
            col_means[col_means == 0] = np.nan
            scaling_factors = 100 / col_means
            scaling_factors = np.nan_to_num(scaling_factors, nan=0.0, posinf=0.0, neginf=0.0)
            tc_m = tc * scaling_factors[np.newaxis, :]
            tc_m = np.nan_to_num(tc_m, nan=0.0, posinf=0.0, neginf=0.0)

            print(f"Run {run}, Depth {depth}: NaNs={np.isnan(tc_m).sum()} / {tc_m.size}")

            baseline = np.median(tc_m[:5], axis=0)
            tc_m = tc_m - baseline

            if filter == 1:
                mean = np.mean(tc_m, axis=0)
                tc_m = signal.detrend(tc_m, axis=0) + mean

                TR = 1.5
                fs = 1 / TR
                lowcut = 0.006
                nyquist = 0.5 * fs
                f_low = lowcut / nyquist
                sos = signal.butter(8, f_low, btype='highpass', fs=fs, output='sos')
                tc_m = signal.sosfiltfilt(sos, tc_m, axis=0)

            proc_tc.append(tc_m)

        if len(proc_tc) == 0:
            print(f"No valid runs for {denoising}, skipping...")
            continue

        mean_proc_tc = np.median(np.array(proc_tc), axis=0)
        psc = mean_proc_tc

        out_path = f'{MAIN_PATH}/pRFM/{subject}/{session}/{denoising}/'
        os.makedirs(out_path, exist_ok=True)
        out_file = f'{out_path}/{subject}_{session}_task-{task}_hemi-LR_desc-avg_bold_{depth}.npy'
        np.save(out_file, psc)
        print(f"Saved PSC to {out_file}")
