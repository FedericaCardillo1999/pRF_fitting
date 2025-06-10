function main_spmmoco_2runs(project, subject, session)
% main_spmmoco_2runs: Motion correction for two-run RestingState using SPM

% Optional: Hide figures
% set(0, 'DefaultFigureVisible','off');
fig = figure;

% Add paths
addpath(genpath('/home2/p315561/programs/spm12'));
addpath(genpath('/home2/p315561/programs/cflaminar/shell/motion_correction'));

% Define paths
mybatchpath = '/home2/p315561/programs/cflaminar/shell/motion_correction/';
myfilespath = ['/scratch/hb-EGRET-AAA/projects/' project '/derivatives/spm/'];

cd(myfilespath)
spm_jobman('initcfg');

% Load batch
cd(mybatchpath)
load('batch_spmmoco_2runs.mat');

% Define session paths
no_moco_path = [myfilespath subject '/ses-' session '/no_moco'];
func_path    = [myfilespath subject '/ses-' session '/func'];

% Unzip functional files
cd(no_moco_path);
niigzFiles = dir('*nii.gz');
for f = 1:numel(niigzFiles)
    niigzFile = niigzFiles(f).name;
    fprintf('Unzipping %s...\n', niigzFile);
    gunzip(niigzFile, func_path);
end

cd(func_path);

% Select only RestingState runs
fprintf('\nSelecting files for RestingState...\n');
pattern1 = ['^sub-' subject '_ses-' session '_task-RestingState_run-1_bold.nii'];
pattern2 = ['^sub-' subject '_ses-' session '_task-RestingState_run-2_bold.nii'];
functionals1 = spm_select('ExtFPListRec', pwd, pattern1, 1:1000);
functionals2 = spm_select('ExtFPListRec', pwd, pattern2, 1:1000);

% Build job
matlabbatch{1}.spm.spatial.realign.estwrite.data = {
    cellstr(functionals1)
    cellstr(functionals2)
                                        }';
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';

% Debug: Print expected mean name
[~, name, ~] = fileparts(functionals1(1,:));
mean_name_guess = ['mean' name '.nii'];
fprintf('Expecting mean image: %s\n', mean_name_guess);

% Run SPM job
spm_jobman('run', matlabbatch);

% List outputs
fprintf('\nMotion correction complete. Output files in:\n%s\n', func_path);
disp(ls([func_path '/*.nii']));

end
