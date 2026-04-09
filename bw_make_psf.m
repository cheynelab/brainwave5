function imageList = bw_make_psf(dsName, covDsName, params, voxelCoordinates, isNormalized)
%
%   
% Written by D. Cheyne Jan 30, 2025
% 
% adapted from bw_make_beamformer to make CTF and PSF images.
% 
% pass same data as for makeBeamformer, plus target voxel location (in CTF coords in cm) 

imageList = [];  % return null list on failure

SPM_BB = [-78 -112 -50 78 76 86];

% check parameters common to all image types before calling mex functions...... 

% check write permission for the .ds folder
isWriteable = bw_isWriteable(dsName);
if ~isWriteable
    return;
end

% check data range for covariance file
covHeader = bw_CTFGetHeader(covDsName);
ctfmin = covHeader.epochMinTime;
ctfmax = covHeader.epochMaxTime;
clear covHeader

dsHeader = bw_CTFGetHeader(dsName);
dsmin = dsHeader.epochMinTime;
dsmax = dsHeader.epochMaxTime;
clear dsHeader
        
% if needed make local copies of head model and voxfile names with full path
if (params.beamformer_parameters.useHdmFile)
    params.beamformer_parameters.hdmFile = fullfile(dsName, params.beamformer_parameters.hdmFile);
    if ~exist(params.beamformer_parameters.hdmFile,'file')
        fprintf('Head model file %s does not exist\n', params.beamformer_parameters.hdmFile);
        return;
    end
end

% ** sanity check that booleans are always passed as int ....

if params.beamformer_parameters.useReverseFilter
    bidirectional = 1;
else
    bidirectional = 0;
end

if ~params.beamformer_parameters.useRegularization
    regularization = 0.0;
else
    regularization = params.beamformer_parameters.regularization;
end

if ~params.beamformer_parameters.filterData 
    params.beamformer_parameters.filter(1) = 0.0;
    params.beamformer_parameters.filter(2) = 0.0;
end

% check that covariance window has been set correctly
if (params.beamformer_parameters.covWindow(1) == 0.0 && params.beamformer_parameters.covWindow(2) == 0.0) | params.beamformer_parameters.covWindow(2) < params.beamformer_parameters.covWindow(1)
    fprintf('Covariance window settings are invalid (%f to %f seconds)\n',params.beamformer_parameters.covWindow);
    return;
end

if (params.beamformer_parameters.covWindow(1) < ctfmin || params.beamformer_parameters.covWindow(2) > ctfmax)
    fprintf('Covariance window settings (%f to %f seconds) are outside of data range (%f to %f seconds)\n',params.beamformer_parameters.covWindow, ctfmin,ctfmax);
    return;
end

[~, ds_name, ~, mri_path, mri_filename] = bw_parse_ds_filename(dsName);
[~, cov_ds_name, ~, ~, ~] = bw_parse_ds_filename(covDsName);

if isNormalized
    % *********************************
    % ** new ** warped volume - create voxfile from MNI coordinates 

    % create a warped MEG voxFile        
    % get transforms
    tfile = sprintf('%s%stransforms.mat',mri_path,filesep);

    if ~exist(tfile,'file')
        errordlg('Could not find transform file %s. You may need to import Freesurfer or CIVET surfaces.', tfile)
    end
    transforms = load(tfile);
    MNI_TO_MEG = transforms.MNI_to_MEG;
    MEG_TO_RAS = transforms.MEG_to_RAS;
    voxelSize = params.beamformer_parameters.stepSize * 10.0;

    % check if ANALYSIS folder has been created
    analysisPath = sprintf('%s%sANALYSIS',dsName, filesep);
    if ~exist(analysisPath,"dir")
        mkdir(analysisPath);
    end

    voxFile = sprintf('%s%sMNI_voxfile_%gmm.vox',analysisPath,filesep, voxelSize);

    voxels = bw_createNormalizedVoxels(MNI_TO_MEG, SPM_BB, voxelSize);
    % voxFile includes orientation, set to 1,0,0
    voxels  = [voxels repmat([1 0 0],size(voxels,1),1)];
    fprintf('writing voxel coordinates to vox file %s...\n', voxFile);
    fid = fopen(voxFile,'w');
    fprintf(fid,'%d\n', size(voxels,1));
    fclose(fid);
    dlmwrite(voxFile, voxels, '-append','delimiter','\t');  

    useVoxFile = 1;
    useNormals = 0;
 
else
    useVoxFile = 0;
    voxFile = ' ';
    useNormals = 0;
end

tic

fprintf('Using covariance dataset %s to compute beamformer weights\n',covDsName);

fprintf('\n******************************\n');
fprintf('Computing crosstalk and point-spread function images ...\n');
fprintf('******************************\n');


% version 5.0 for affine normalized images.....


% call mex function to generate crosstalk and PSF images and save as volumes...
% 
[imageList] = bw_makeCrossTalkImages(dsName, covDsName, params.beamformer_parameters.hdmFile,...
           params.beamformer_parameters.useHdmFile, params.beamformer_parameters.filter, params.beamformer_parameters.boundingBox, ...
           params.beamformer_parameters.stepSize, params.beamformer_parameters.covWindow, voxFile, useVoxFile, useNormals,...
           params.beamformer_parameters.baseline, params.beamformer_parameters.useBaselineWindow, params.beamformer_parameters.sphere,...
           params.beamformer_parameters.noise, regularization, bidirectional, voxelCoordinates);



toc

disp('Done generating images...')  

% ************************ 
% post-processing 
% 

if ~isNormalized
    %  .svl files have been created...
    imageset.isNormalized = false;
    imageset.imageList{1} = imageList;
    if params.beamformer_parameters.useBrainMask  
        maskFile = fullfile(mri_path, params.beamformer_parameters.brainMaskFile);
        bw_maskSvlImages(imageList,mri_filename, maskFile);
    end

else

    % have to convert *.txt image files to MNI volumes 
    % ** note MNI voxels must match order in voxFile used to create
    % the text files in imageList ***

            
    if params.beamformer_parameters.useBrainMask    
        maskFile = fullfile(mri_path, params.beamformer_parameters.brainMaskFile);
        bw_apply_BrainMask(voxels, imageList, maskFile, MEG_TO_RAS);  
    end

    normalized_imageList = bw_txt2mni(SPM_BB, voxelSize, imageList);         

    if isempty(normalized_imageList)
        errordlg('Could not normalize images for plotting... exiting');
        return;
    end

    imageset.isNormalized = true;
    imageset.imageList{1} = char(normalized_imageList);           

end

imageset.imageType = 'Volume';
% new create an imageset mat file for multiple images.
    
imageset.mriName{1} = mri_filename;        


imageset.no_subjects = 1;
imageset.params = params;
imageset.no_images = size(imageList,1);

imageset.dsName{1} = ds_name;
imageset.covDsName{1} = cov_ds_name;
imageset.isNormalized = false;

imageset.cond1Label = 'Single Subject';

% generate imageset name
tname = char(imageList(1,:));
imageset_BaseName=tname(1,1:strfind(tname,'Hz')+1);  
imageset_BaseName = sprintf('%s_voxel_%.2f_%.2f_%.2f', imageset_BaseName, voxelCoordinates);

% save and plot CTF 
filelist = imageset.imageList{1};
imageset.imageList{1} = filelist(1,:);    
imagesetName = sprintf('%s_CTF.mat', imageset_BaseName);
fprintf('Saving CTF image set information in %s\n', imagesetName);
save(imagesetName, '-struct', 'imageset');
bw_mip_plot_4D(imagesetName);   

% save and plot PSF   
imageset.imageList{1} = filelist(2,:);
imagesetName = sprintf('%s_PSF.mat', imageset_BaseName);
fprintf('Saving CTF image set information in %s\n', imagesetName);
save(imagesetName, '-struct', 'imageset');
bw_mip_plot_4D(imagesetName);   


end