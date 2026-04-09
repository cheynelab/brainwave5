function bw_apply_BrainMask(voxels, imageList, maskFile, MEG_TO_RAS)
%   %   function bw_apply_BrainMask( imageList, maskFile )
%
%   DESCRIPTION: stand-alone routine to apply a binary mask to a list of images
%               * assumes these are text files for normalized MNI volumes
%               ** overwrites the existing files...
%
             
    if ~exist(maskFile,'file')
        fprintf('*** WARNING brain mask file %s not found .. skipping this step ***\n', maskFile)
        return;
    end

    mask_nii = load_nii(maskFile);
    fprintf('Reading MRI mask file %s..\n', maskFile);   
    
    % convert MEG voxels in voxFile to RAS coordinates
    fprintf('converting MEG voxels to RAS mask coordinates...\n')
    % convert meg coords to RAS 

    numVoxels = size(voxels,1);
    temp = [voxels(:,1:3) ones(numVoxels,1) ];
    coords = temp * MEG_TO_RAS;  % transform to mni coordinates and scale to cm
    coords(:,4) = [];
    ras_coords = round(coords);
    nMask = size(ras_coords,1); % sanity check

    % make linear mask, set non-zero voxels to 1 else 0
    maskImg = mask_nii.img;
    [nx, ny, nz] = size(maskImg);
    linMask = zeros(numVoxels,1);
    xc = ras_coords(:,1);
    yc = ras_coords(:,2);
    zc = ras_coords(:,2);
    if ( any(xc < 1) || any(xc > nx) || any(yc < 1) || any(yc > ny) || any(zc < 1) || any(zc > nz) )
        % skip voxel if out of bounds (shouldn't happen)
    else
        for k=1:size(ras_coords,1)
            x = ras_coords(k,1);
            y = ras_coords(k,2);                              
            z = ras_coords(k,3);
            value = maskImg(x,y,z);
            if value > 0
                linMask(k) = 1;
            end                  
        end
    end

    % read each image and save after masking
    for k=1: size(imageList,1)

        file = deblank(char(imageList(k,:)));
        fprintf('Applying mask to file %s ..\n', file)

        Img = importdata(file);
        nVox = size(Img,1);
        if nMask ~= nVox 
            fprintf('Mismatch between size of normalized voxel mask and image...\n');
        else
            % ** overwrite non-masked image **
            newImg = Img .* linMask;
            dlmwrite(file, newImg, 'delimiter','\n');  
        end
    end
end

