function bw_maskSvlImages(imageList,mriFile, maskFile)
    
    if ~exist(maskFile,'file')       
        fprintf('*** WARNING brain mask file %s not found .. skipping this step ***\n', maskFile);
        return;
    end
    % create binary mask voxel list (is same for all images)     
    mri_nii = load_nii(maskFile);
    fprintf('Reading MRI mask file %s, Voxel dimensions: %g %g %g\n',...
        maskFile, mri_nii.hdr.dime.pixdim(2), mri_nii.hdr.dime.pixdim(3), mri_nii.hdr.dime.pixdim(4));   

    fprintf('Computing binary mask for imaging volume\n');
    % need MEG to RAS transformation matrix
    matt = strrep(mriFile,'.nii','.mat');
    t = load(matt);
    M = bw_getAffineVox2CTF(t.na, t.le, t.re, t.mmPerVoxel );
    meg2ras = inv(M);

    % get svl parameters from first image
    svlFile = deblank(char(imageList(1,:)));         
    svlImg = bw_readSvlFile(svlFile);
    boundingBox = svlImg.bb;
    stepSize = svlImg.mmPerVoxel * 0.1;
    samUnits = svlImg.samUnits;

    % generate the image voxel list and convert to RAS voxels
    xVoxels = boundingBox(1):stepSize:boundingBox(2);
    yVoxels = boundingBox(3):stepSize:boundingBox(4);
    zVoxels = boundingBox(5):stepSize:boundingBox(6);
    nVoxels = size(xVoxels,2) * size(yVoxels,2) * size(zVoxels,2); 
    n = 1;
    voxelMask = zeros(1,nVoxels);
    maskCount = 0;
    for i=1:size(xVoxels,2)
        for j=1:size(yVoxels,2)
            for k=1:size(zVoxels,2)
                p = [xVoxels(i) yVoxels(j) zVoxels(k)] * 10.0;
                v = round( [p 1] * meg2ras);
%                     fprintf('head coord, voxel %d %d %d, %g %g %g\n', p(1:3), v(1:3));
                if any(v < 1) || any(v > 256) 
                    % skip voxel
                else
                    maskval = mri_nii.img(v(1), v(2), v(3));
                    if maskval > 0 
                        voxelMask(n) = 1;
                        maskCount = maskCount + 1;                        
                    end        
                end
                n = n+1;
            end
        end
    end
    fprintf('Mask contains %d non-zero values ...\n', maskCount);
          
    % change in ver 5.0 - don't need to save non-masked files since
    % they are not saved in imageSet...
    for k=1:size(imageList,1)    
        svlFile = deblank(char(imageList(k,:)));    
        fprintf('applying brain mask to %s...\n', svlFile);
        
        svlImg = bw_readSvlFile(svlFile);

        maskedImg = double(svlImg.Img(:));
        maskedImg = voxelMask' .* maskedImg;  

        bw_writeSvlFile(svlFile, boundingBox,  stepSize, samUnits, maskedImg);
    end      

end

   