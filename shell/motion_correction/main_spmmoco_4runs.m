function main_spmmoco_4runs(projectName, subject, session)
% Avoid using 'path' as a variable
fig = figure;
addpath(genpath('/home2/p315561/programs/spm12'));
addpath(genpath('/home2/p315561/programs/cflaminar/shell/motion_correction'));

baseDir = ['/scratch/hb-EGRET-AAA/projects/' projectName];
spmDir = [baseDir '/derivatives/spm/'];
batchDir = '/home2/p315561/programs/cflaminar/shell/motion_correction/';

cd(spmDir);  % This will now work if the projectName is correct
spm_jobman('initcfg');

cd(batchDir);
load('batch_spmmoco_4runs.mat');

noMoCoDir = [spmDir subject '/ses-' session '/no_moco'];
funcDir   = [spmDir subject '/ses-' session '/func'];

% Unzip files
cd(noMoCoDir);
niigzFiles = dir('*nii.gz');
for f = 1:numel(niigzFiles)
    gunzip(niigzFiles(f).name, funcDir);
end

cd(funcDir);
functionals1 = spm_select('ExtFPListRec', pwd, '^.*run-1_bold.nii$', 1:1000);
functionals2 = spm_select('ExtFPListRec', pwd, '^.*run-2_bold.nii$', 1:1000);
functionals3 = spm_select('ExtFPListRec', pwd, '^.*run-3_bold.nii$', 1:1000);
functionals4 = spm_select('ExtFPListRec', pwd, '^.*run-4_bold.nii$', 1:1000);

matlabbatch{1}.spm.spatial.realign.estwrite.data = {
    cellstr(functionals1)
    cellstr(functionals2)
    cellstr(functionals3)
    cellstr(functionals4)
}';

matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];

spm_jobman('run', matlabbatch);
end
