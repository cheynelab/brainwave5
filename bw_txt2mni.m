% convert *.txt image files to MNI volume


function normalized_imageList = bw_txt2mni(SPM_BB, voxelSize, imageList)
    
    SPM_ORIGIN = [SPM_BB(1) SPM_BB(2) SPM_BB(3)];
    
    % compute voxel origin from corner of bounding box 
    xo = abs((SPM_BB(1) / voxelSize) ) + 1; % add one for zero, don't round
    yo = abs((SPM_BB(2) / voxelSize) ) + 1;  % add one for zero, don't round
    zo = abs((SPM_BB(3) / voxelSize) ) + 1; % add one for zero, don't round
    VOXEL_ORIGIN = [xo yo zo];
    
    nx = round( (SPM_BB(4) - SPM_BB(1)) / voxelSize ) + 1;
    ny = round( (SPM_BB(5) - SPM_BB(2)) / voxelSize ) + 1;
    nz = round( (SPM_BB(6) - SPM_BB(3)) / voxelSize ) + 1;
    nvoxels = nx * ny * nz;
    dataType = 64;  % DOUBLE

    fprintf('Normalizing image text files to MNI volumes (%d voxels)...\n', nvoxels);
    
    for k=1: size(imageList,1)
           
        file = deblank(char(imageList(k,:)));
        fprintf('Converting %s to NIfTI...\n', file)
        
        Img = importdata(file);
    
        % sanity check
        if size(Img) ~= nvoxels
            msg = sprintf('mismatch between image size (%d voxels) and volume size (%d voxels)', size(Img), nvoxels);
            errordlg(msg)
        end
        
        % put image in correct orientation
        Img = reshape(Img,nx,ny,nz);
    
        [p,n] = fileparts(file);
        wn = strcat('w',n);
        niiFile = fullfile(p,[wn '.nii']);

        nii = make_nii(Img, voxelSize, VOXEL_ORIGIN, dataType);
    
        nii.hdr.dime.pixdim = [1 voxelSize voxelSize voxelSize 1 1 1 1];
        nii.hdr.dime.vox_offset = 352; % not set?
        nii.hdr.hist.sform_code = 1;
        nii.hdr.hist.srow_x = [voxelSize 0 0 SPM_ORIGIN(1)];
        nii.hdr.hist.srow_y = [0 voxelSize 0 SPM_ORIGIN(2)];
        nii.hdr.hist.srow_z = [0 0 voxelSize SPM_ORIGIN(3)];
        nii.hdr.hist.originator = VOXEL_ORIGIN;
        nii.hdr.hist.descrip = 'BrainWave MNI normalized';
        nii.hdr.hist.qoffset_x = SPM_ORIGIN(1);
        nii.hdr.hist.qoffset_y = SPM_ORIGIN(2);
        nii.hdr.hist.qoffset_z = SPM_ORIGIN(3);
    
        save_nii(nii,niiFile);
    
        c_list{k} = niiFile;
    end
    
    normalized_imageList = c_list';
