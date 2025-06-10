function main_spmmoco_3runs(project, subject, session)
%set(0, 'DefaultFigureVisible','off');
fig = figure;
addpath(genpath('/home2/p315561/programs/spm12'));
addpath(genpath('/home2/p315561/programs/cflaminar/shell/motion_correction'));

mybatchpath = '/home2/p315561/programs/cflaminar/shell/motion_correction/';
myfilespath = ['/scratch/hb-EGRET-AAA/projects/' project '/derivatives/spm/'];
cd(myfilespath)
spm_jobman('initcfg');

cd(mybatchpath)
load('batch_spmmoco_3runs.mat');

% Construct paths dynamically based on subject and session
no_moco_path = [myfilespath subject '/ses-' session '/no_moco'];
func_path    = [myfilespath subject '/ses-' session '/func'];

% Unzip functional files
cd(no_moco_path);
niigzFiles = dir('*nii.gz');
for f = 1:numel(niigzFiles)
    niigzFile = niigzFiles(f).name;
    gunzip(niigzFile, func_path);
end

% Select functional volumes
cd(func_path);
functionals1 = spm_select('ExtFPListRec', pwd, '^.*run-1_bold.nii$', 1:1000);
functionals2 = spm_select('ExtFPListRec', pwd, '^.*run-2_bold.nii$', 1:1000);
functionals3 = spm_select('ExtFPListRec', pwd, '^.*run-3_bold.nii$', 1:1000);

matlabbatch{1}.spm.spatial.realign.estwrite.data = {
    cellstr(functionals1)
    cellstr(functionals2)
    cellstr(functionals3)
                                        }';

matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];

spm_jobman('run', matlabbatch)

end
