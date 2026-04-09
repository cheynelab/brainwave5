function success = bw_importCoregistration(coreg_path, mri_dir, filetype)


success = 0;
% finish up by creating convex hull around gray surface mesh
if strcmp(filetype, 'freesurfer')

    
    %%%%%%
    % create transforms.mat file and save in _MRI folder
    %%%%

    % 1. get MEG to RAS  transformation 
 
    [~, n, ~] = fileparts(mri_dir);
    postfix = regexp(n, '_MRI');
    subjID = n(1:(postfix(end)-1));
    matfile = fullfile(mri_dir, strcat(subjID,'.mat'));
    tmat = load(matfile);       
    M = tmat.M;             % voxel-to-head transformation matrix    
    RAS_to_MEG = M * diag([0.1,0.1,0.1,1]);     % include scaling to cm
    MEG_to_RAS = inv(RAS_to_MEG);


    % 2. get voxel to MNI transformation 
    
    transformPath = sprintf('%s%smri%stransforms%s',coreg_path, filesep,filesep,filesep);

    transformFile = sprintf('%stalairach.xfm',transformPath);
    fprintf('looking for transformation file (%s)\n', transformFile);

    if exist(transformFile,'file') ~= 2
        [tname, tpath, ~] = uigetfile(...
           {'*.xfm','Talairach transform (*.xfm)'},'Select the talairach transform file',mesh_dir);    
        if isequal(tname, 0) || isequal(tpath, 0)
            delete(wbh);
            return;
        end
       transformFile = fullfile(tpath, tname);
    end   
    t = importdata(transformFile);
    transform = [t.data; 0 0 0 1];
                  
    % get RAS to MNI affine transformation    
    RAS_to_MNI = transform';      
    % 
    % talairach.xfm is for voxels - need to add scaling to mm    
    scaleM = [tmat.mmPerVoxel 0 0 0; 0 tmat.mmPerVoxel 0 0; 0 0 tmat.mmPerVoxel 0; 0 0 0 1];
    RAS_to_MNI = scaleM * RAS_to_MNI;


    %%%%
    % 3. create direct MNI to MEG transformation
    
    %%%
    MNI_to_MEG = inv(RAS_to_MNI) * inv(MEG_to_RAS);

    tfile = fullfile(mri_dir, 'transforms.mat');
    transforms.RAS_to_MNI = RAS_to_MNI;
    transforms.MEG_to_RAS = MEG_to_RAS;
    transforms.MNI_to_MEG = MNI_to_MEG;

    fprintf('Saving transforms in file %s\n', tfile);
    save(tfile ,'-struct', 'transforms'); 
    
    %%%%%%%%%%%%%%%%%%%%%
    % save copy of brain mask

    % convert and save a copy of freesurfer brainmask.mgz
    % this is already co-registered with <subjID>.nii
    % however has to be converted from .mgz to .nii which requires
    % mri_convert 
    
    % check for path to freesurfer bin directory - might be in
    % subdirectory! 

    % check if freesurfer is already in path so it doesn't get added
    % multiple times
    matlab_path = getenv('PATH');
    foundFS = contains(matlab_path,'freesurfer');
    
    if ~foundFS 
        % try to look for it
        test = '/Applications/freesurfer/bin/mri_convert';
        if exist(test,'file')
            [fspath,~,~] = fileparts(test);
            matlab_path = getenv('PATH');
            setenv('PATH', [matlab_path, ':/Applications/freesurfer', ':/Applications/freesurfer/bin'])
            addpath(fspath);
            foundFS = true;
        else
            test = '/usr/local/freesurfer/bin/mri_convert';       
            if exist(test,'file')
                [fspath,~,~] = fileparts(test);
                matlab_path = getenv('PATH');
                setenv('PATH', [matlab_path, ':/Applications/freesurfer', ':/Applications/freesurfer/bin'])
                addpath(fspath);    
                foundFS = true;
            end
        end
        if ~foundFS
            response = questdlg('Cannot find installed version of Freesurfer. Do you want to look for it?','Init Freesurfer','Yes','No, Continue anyway','Yes');
            if strcmp(response,'Yes')
                fspath = uigetdir;
                matlab_path = getenv('PATH');
                setenv('PATH', [matlab_path, ':/Applications/freesurfer', ':/Applications/freesurfer/bin'])
                addpath(fspath);
                foundFS = true;
            end
        end
    end
    
    if ~foundFS
        fprintf('** Warning: Freesurfer must be installed ...\n')
        return;
    end
    
    maskFileZ = sprintf('%s%s%s%sbrainmask.mgz', coreg_path, filesep,'mri',filesep );
    maskFile = fullfile(mri_dir, 'brainmask.nii');
    fprintf('saving freesurfer brain mask %s to %s\n', maskFileZ, maskFile);
    cmd = sprintf('mri_convert %s %s', maskFileZ, maskFile);
    system(cmd);


    if exist(maskFile,'file')

        % get the mask image
        nii = load_nii(maskFile);        
        % mask should match MRI resolution and dimensions!
        Img = nii.img;      

        % get RAS coordinates of non-zero voxels
        % and convert to MEG (head) coordinates
        idx = find(Img > 0);
        [x, y, z] = ind2sub( size(Img), idx);
        voxels = [x y z ones(size(x,1),1) ];
        headpts = voxels * RAS_to_MEG;
        headpts(:,4) = [];
            
        fprintf('Creating convex hull from brain mask...\n');

        % create convex hull of brain mask in MEG coordinates
        points = double(headpts);
        idx = convhulln(points);
        headpts = points(idx,:);    

        shapefile = fullfile(mri_dir, strcat(subjID, '_brainHull.shape'));

        % get updated array size!
        npts = size(headpts,1);
        fprintf('writing %d points to shape file (%s)\n', npts, shapefile);
        fid = fopen(shapefile,'w');
        fprintf(fid, '%d\n', npts);
        for k=1:npts
            fprintf(fid,'%6.2f %6.2f  %6.2f\n', headpts(k,1), headpts(k,2), headpts(k,3));
        end
        fclose(fid);  

    end

    success = 1;
    fprintf('\n**************************************************************************\n');
    fprintf('Successfully imported MNI co-registration files:\n');
    fprintf('Transforms saved in %s:\n', tfile);
    if exist(maskFile,'file')
        fprintf('Brain mask saved in %s:\n', maskFile);
    end
    if exist(maskFile,'file')
        fprintf('Brain hull shape saved in %s:\n', shapefile);
    end

    % look for already created head surface
    headSurfaceFile = sprintf('%s%ssurf%slh.seghead',coreg_path, filesep,filesep);
    headFile = fullfile(mri_dir, strcat(subjID, '_head_surface'));

    if exist(headSurfaceFile,'file')
        fprintf('Found head surface mesh %s\n...saving as %s \n', headSurfaceFile, headFile);
        cmd = sprintf('cp %s %s',headSurfaceFile, headFile);
        system(cmd);
    else
        fprintf('No head surface saved (requires -all option)... \n')
        % try to create one  *** getting errors with system command due to
        % hypen in command string ....
        % 
        % fprintf('Trying to create head surface (requires -all option)... \n')
        % cmdstr = sprintf(' -i %s -surf %s', coreg_path, headSurfaceFile)
        % system(cmd)  
        % if err == 0
        %     fprintf('Saving head surface mesh %s\n...saving as %s \n', headSurfaceFile, headFile);
        % end
    end


    fprintf('**************************************************************************\n');
   
elseif strcmp(filetype, 'civet')

    %%%%%%
    % create transforms.mat file and save in _MRI folder
    %%%%

    % 1. get MEG to RAS  transformation 
 
    [~, n, ~] = fileparts(mri_dir);
    postfix = regexp(n, '_MRI');
    subjID = n(1:(postfix(end)-1));
    matfile = fullfile(mri_dir, strcat(subjID,'.mat'));
    tmat = load(matfile);       
    M = tmat.M;             % voxel-to-head transformation matrix    
    RAS_to_MEG = M * diag([0.1,0.1,0.1,1]);     % include scaling to cm
    MEG_to_RAS = inv(RAS_to_MEG);


    % 2. get voxel to MNI transformation 
    
    % look for .xfm file in default location
    transformPath = sprintf('%s%stransforms%slinear%s',coreg_path,filesep,filesep,filesep);

    % get xfm file - also provides subject name in filename
    t_files = dir(fullfile(transformPath,'*tal.xfm'));
    if isempty(t_files)
        return;
    end

    % subject name is everything after civet_ and before _t1
    idx = strfind(t_files.name,'_');
    idx2 = strfind(t_files.name,'_t1');
    subj_name = t_files.name(idx(1)+1: idx2(1)-1);

    s = sprintf('civet_%s_t1_tal.xfm',subj_name);
    transformFile = fullfile(transformPath,s);
    fprintf('looking for transformation file (%s)\n', transformFile);

    t = importdata(transformFile);
    transform = [t.data; 0 0 0 1];
    fprintf('transforming mesh from MNI to original NIfTI coordinates using transformation:\n');

    mni_to_ras = inv(transform)';
    % 4.3 - have to put this mm to voxel scaling in the saved MNI_to_RAS transform! 
    % opposite to FS (voxel to mm) is applied after e.g., translation 
    scaleM = [1/tmat.mmPerVoxel 0 0 0; 0 1/tmat.mmPerVoxel 0 0; 0 0 1/tmat.mmPerVoxel 0; 0 0 0 1];
    mni_to_ras = mni_to_ras * scaleM;

    RAS_to_MNI = inv(mni_to_ras);  % for saving opposite transform



    %%%%
    % 3. create direct MNI to MEG transformation
    
    %%%
    MNI_to_MEG = inv(RAS_to_MNI) * inv(MEG_to_RAS);

    tfile = fullfile(mri_dir, 'transforms.mat');
    transforms.RAS_to_MNI = RAS_to_MNI;
    transforms.MEG_to_RAS = MEG_to_RAS;
    transforms.MNI_to_MEG = MNI_to_MEG;

    fprintf('Saving transforms in file %s\n', tfile);
    save(tfile ,'-struct', 'transforms'); 
    
    %%%%%%%%%%%%%%%%%%%%%
    % 4. since brain mask is not aligned to original T1 image have to use
    % cortical surface 

    % find white surfaces
    t_files = dir(fullfile(coreg_path, 'surfaces','*white_surface_rsl*'));
    if isempty(t_files)
        return;
    end
    file = fullfile(coreg_path, 'surfaces', t_files(1).name);           
    [~, meshdata] = bw_readMeshFile(file);
    pial_left = meshdata;  
    file = fullfile(coreg_path, 'surfaces', t_files(2).name);            
    [~, meshdata] = bw_readMeshFile(file);
    pial_right = meshdata;  

    % concatenate hemispheres - CIVET vertices should be in MNI
    pial_vertices = [pial_left.vertices; pial_right.vertices];

    % use surf2solid to make brain mask????
    maskFile = '';

    if ~isempty(pial_vertices)
            
        fprintf('Creating convex hull from brain mask...\n');

        % create convex hull of brain mask in MEG coordinates
        x = pial_vertices(:,1);
        y = pial_vertices(:,2);
        z = pial_vertices(:,3);        
        voxels = [x y z ones(size(x,1),1) ];
        headpts = voxels * MNI_to_MEG;
        headpts(:,4) = [];

        points = double(headpts);
        idx = convhulln(points);
        headpts = points(idx,:);    

        shapefile = fullfile(mri_dir, strcat(subjID, '_brainHull.shape'));

        % get updated array size!
        npts = size(headpts,1);
        fprintf('writing %d points to shape file (%s)\n', npts, shapefile);
        fid = fopen(shapefile,'w');
        fprintf(fid, '%d\n', npts);
        for k=1:npts
            fprintf(fid,'%6.2f %6.2f  %6.2f\n', headpts(k,1), headpts(k,2), headpts(k,3));
        end
        fclose(fid);  

    end

    success = 1;
    fprintf('\n**************************************************************************\n');
    fprintf('Successfully imported MNI co-registration files:\n');
    fprintf('Transforms saved in %s:\n', tfile);
    if exist(maskFile,'file')
        fprintf('Brain mask saved in %s:\n', maskFile);
    end
    if exist(maskFile,'file')
        fprintf('Brain hull shape saved in %s:\n', shapefile);
    end
    fprintf('**************************************************************************\n');
   
end

end
