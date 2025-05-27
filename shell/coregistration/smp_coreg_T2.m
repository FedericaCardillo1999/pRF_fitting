% coregister_script.m
% Add SPM to the MATLAB path (adjust the path to your SPM installation)
addpath('/home2/p315561/programs/spm12');


% Initialize SPM without GUI
spm('defaults', 'fmri');
spm_jobman('initcfg');

% Get subject and session from command-line input
subject = getenv('SUBJECT_ID');
session = getenv('SESSION_ID');

% Define paths using the variables
fixed_image = sprintf('/scratch/hb-EGRET-AAA/projects/EGRET3A/derivatives/denoised/sub-%s/ses-01/sub-%s_ses-01_acq-MPRAGE_T1w.nii', subject, subject);
moved_image = sprintf('/scratch/hb-EGRET-AAA/projects/EGRET3A/sub-%s/ses-%s/anat/sub-%s_ses-%s_acq-spacecorp2iso_run-1_T2w.nii', subject, session, subject, session);

% Setup the co-registration and reslicing job
matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {fixed_image};
matlabbatch{1}.spm.spatial.coreg.estwrite.source = {moved_image};
matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''}; % Leave empty if no other images
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = ...
    [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4; % Spline interpolation
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';

% Run the job
spm_jobman('run', matlabbatch);