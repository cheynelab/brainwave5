%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [imagesetName] = bw_generate_group_images(groupPath, list, list2, covList, params)
%
%   DESCRIPTION: stand-alone routine to generate a group image from a passed 
%   list of datasets - was separate function in bw_group_images.m
%
% (c) D. Cheyne, 2014. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
% 
% Version 4.0 March 2022 - removed optional averaging over CIVET surfaces.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [imagesetName] = bw_generate_group_images(groupPrefix, list, list2, covList, params, label1, label2)


    SPM_BB = [-78 -112 -50 78 76 86];


    imagesetName = [];
    
    if ~exist('label1','var')
        label1 = 'Condition1';
    end
    
    if ~exist('label2','var')
        label2 = 'Condition2';
    end
    
    % fix for inconsistency in paths for imageset files
    % put group analysis folders in subfolder GROUP_ANALYSIS
    [~, name, ext] = bw_fileparts(groupPrefix);
    groupName = fullfile(name,ext);

    groupPath = strcat('GROUP_ANALYSIS',filesep,groupName);
    if ~exist(groupPath,'dir')    
        mkdir(groupPath);
    end
    
    imageset.no_subjects = size(list,2);
    
    % save parameters and options that were used to generate this average
    imageset.params = params;
       
    wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wbh,'canceling',0)
       
    % first generate images for all subjects and timepoints and save in
    % individual files in subject directories 
    global_min = 0.0;
    global_max = 0.0;
            
    for n=1:imageset.no_subjects
                
        if getappdata(wbh,'canceling')
            delete(wbh);   
            fprintf('*** cancelled ***\n');
            return;
        end
        waitbar(n/imageset.no_subjects,wbh,sprintf('generating images for subject %d',n));
     
        dsName = deblank( list{1,n} );
        
        imageset.dsName{n} = dsName;
        
        % *** generate images for this subject *** 
        [~, ~, ~, mri_dir, mri_filename] = bw_parse_ds_filename(dsName);   % need MRI name and path for this subject   
      
        % create contrast images...
        if isempty(mri_filename)
            s = sprintf('Could not locate mri file for dataset %s. Cannot normalize images...\n', dsName);
            errordlg(s);
            delete(wbh);
            return;
        end 
        
        % new 4.2 - contrast dataset can also be different SAM baseline
        % dataset if option selected.
        if params.beamformer_parameters.contrastImage | params.beamformer_parameters.multiDsSAM
            if isempty(list2)
                fprintf('List2 is blank...\n');   
                return;
            end
            contrastDsName = deblank( list2{1,n} );
            imageset.contrastDsName{n} = contrastDsName;
      
            % check subjID mismatch
            [~, ~,subjectID, ~, ~] = bw_parse_ds_filename(dsName);
            [~, ~, subjectID2, ~, ~] = bw_parse_ds_filename(contrastDsName);        
            if ~strcmp(subjectID,subjectID2)
                errordlg('Selected Dataset and Contrast Dataset must have same subject ID');
                return;
            end
        end

        % get covariance dataset...
        if isempty(covList)
            fprintf('Covariance list is blank...\n');   
            return;
        else
            covDsName  = deblank( covList{1,n} );
            imageset.covDsName{n} = covDsName;
        end            
        % check subjID mismatch
        [~, ~,subjectID, ~, ~] = bw_parse_ds_filename(dsName);
        [~, ~, subjectID2, ~, ~] = bw_parse_ds_filename(covDsName);        
        if ~strcmp(subjectID,subjectID2)
            errordlg('Selected Dataset(s) and Covariance Dataset must have same subject ID');
            return;
        end  
        
        % *** generate images for list 1
        fprintf('processing dataset -> %s ...\n', dsName);   
        
        % special case - if contrast dataset selected for SAM pseudoT or pseudoF AND use multiDs option selected
        if ( strcmp(params.beamformer_parameters.beam.use,'T') | strcmp(params.beamformer_parameters.beam.use,'F') ) && ...
                params.beamformer_parameters.contrastImage & params.beamformer_parameters.multiDsSAM
            doMultiDsSAM = 1;
        else
            doMultiDsSAM = 0;
        end
        

        % *********************************
        % ** new ** warped volume - create voxfile from MNI coordinates 

        % create a warped MEG voxFile        
        % get transforms
        tfile = sprintf('%s%stransforms.mat',mri_dir,filesep);

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
        fprintf('writing voxel MEG coordinates to vox file %s...\n', voxFile);
        fid = fopen(voxFile,'w');
        fprintf(fid,'%d\n', size(voxels,1));
        fclose(fid);
        dlmwrite(voxFile, voxels, '-append','delimiter','\t');  

        params.beamformer_parameters.voxFile = voxFile;
        params.beamformer_parameters.useVoxFile = 1;

        if doMultiDsSAM
            fprintf('using dataset --> %s for SAM active window ...\n', dsName);              
            fprintf('using dataset --> %s for SAM baseline window ...\n', contrastDsName);              
            imageList = bw_make_beamformer(dsName, contrastDsName, params.beamformer_parameters);           
        
            if isempty(imageList)
                delete(wbh);
                return;
            end
        else
            fprintf('using dataset --> %s for covariance calculation...\n', covDsName);
            imageList = bw_make_beamformer(dsName, covDsName, params.beamformer_parameters);           

            % *** if we are creating a contrast image, generate images for list 2...
            if params.beamformer_parameters.contrastImage
                fprintf('\ncreating constrast images using dataset --> %s ...\n', contrastDsName);
                fprintf('using dataset --> %s for covariance calculation...\n', covDsName);
                imageList2 = bw_make_beamformer(contrastDsName, covDsName, params.beamformer_parameters);
                if isempty(imageList2)
                    delete(wbh);
                    return;
                end
            end
            
        end
        
        % have to apply mask to text files in CTF coordinates *before* normalization as .nii file
        if params.beamformer_parameters.useBrainMask
            maskFile = fullfile(mri_dir, params.beamformer_parameters.brainMaskFile);
            bw_apply_BrainMask(voxels, imageList, maskFile, MEG_TO_RAS);   
            if params.beamformer_parameters.contrastImage & ~doMultiDsSAM
                bw_apply_BrainMask(voxels, imageList2, maskFile, MEG_TO_RAS);          
            end
        end

        % have to convert *.txt image files to MNI volumes 
        % ** note MNI voxels must match order in voxFile used to create
        % the text files in imageList ***
        
        normalized_imageList = bw_txt2mni(SPM_BB, voxelSize, imageList);         
        imageset.mriName{n} = mri_filename;        
        imageset.isNormalized = true;

        if isempty(normalized_imageList)
            errordlg('Could not normalize images for plotting... exiting');
            return;
        end

        if params.beamformer_parameters.contrastImage & ~doMultiDsSAM
            normalized_imageList2 = bw_txt2mni(SPM_BB, voxelSize, imageList2);           
            if isempty(normalized_imageList2)
                errordlg('Could not normalize images for plotting... exiting');
                return;
            end

            for k=1:size(normalized_imageList,1)
               file1 = deblank( char(normalized_imageList(k,:)) );               
               file2 = deblank( char( normalized_imageList2(k,:)) );
               [path, imageName, ext] = bw_fileparts(file1);                   
               file = sprintf('%s%s%s-%s,%s%s', path,filesep, dsName, contrastDsName, imageName, ext);
               bw_make_contrast_image(file1, file2, file); 
               diff_imageList{k} = file;    
            end
            imageset.imageList{n} = char(diff_imageList);

        else
            imageset.imageList{n} = char(normalized_imageList);
        end

        imageset.no_images = size(imageList,1);   % for now this is same for each ...       

    end  % for n subjects
    
    delete(wbh); 
                
    % generate grand averages and save in named directory 
    
    % have to image across subjects for each latency 
    % by parsing the subject x latency image lists      
                   
    for k=1:imageset.no_images
        for j=1:imageset.no_subjects
             slist = char( imageset.imageList(j) );
             tlist{j} = slist(k,:);
        end
        aveList = deblank(tlist');
        name = char(aveList(1,:));
        [~, basename, ~] = fileparts(name);
        % bug fix ver 4.1 - if using mean option 
        idx = strfind(basename,'time');
        if isempty(idx)
            idx = strfind(basename,'_A')+1;
        end
        fileID = basename(idx(1):end);

        if params.beamformer_parameters.contrastImage && ~doMultiDsSAM
            if params.beamformer_parameters.useSurfaceFile
                aveName = sprintf('%s%s%s_cond1-cond2_%s_AVE.txt', groupPath,filesep,groupName, fileID);        
            else
                aveName = sprintf('%s%s%s_cond1-cond2_%s_AVE.nii', groupPath,filesep,groupName, fileID);
            end
        else
            if params.beamformer_parameters.useSurfaceFile
                aveName = sprintf('%s%s%s_%s_AVE.txt', groupPath,filesep,groupName, fileID );        
            else
                aveName = sprintf('%s%s%s_%s_AVE.nii', groupPath,filesep,groupName, fileID );
            end     
        end

        aveName = deblank(aveName);
        fprintf('generating average -->%s\n', aveName);

        bw_average_images(aveList, aveName);       

        % save average names for plotting...
        imageset.averageList{k} = aveName; 
        
        % not used
        imageset.averageSurface = [];

    end
       
            
    % save data range for faster initializing of plots...
    imageset.global_max = global_max;
    imageset.global_min = global_min;
    
    imageset.cond1Label = label1;
    imageset.cond2Label = label2;

    % save image set info - this should be all that is needed to plot
    % images independently of # of latecies or files...
    imagesetName = sprintf('%s%s%s_IMAGES.mat', groupPath,filesep,groupName);
    
    
    fprintf('Saving images in %s\n', imagesetName);
    save(imagesetName, '-struct', 'imageset');
     
end


