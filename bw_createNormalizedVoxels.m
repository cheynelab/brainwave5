%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function voxels = bw_createNormalizedVoxels(mni2meg, boundingBox, mmPerVoxel)
%
%   create a normalized list of voxels using the passed affine
%   transformation matrix (e.g., from MNI coordinates to MEG coordinates)
%   input:
%   transform   = affine transformation from MNI coordinates to the
%                 target coordinate system 
%   boundingBox = bounding box of the MNI volume
%   mmPerVoxel =  voxel size of the MNI volume
%
%   (c) D. Cheyne, 2025. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function voxels = bw_createNormalizedVoxels(mni2meg, boundingBox, mmPerVoxel)

    version = 5.0;
    fprintf('bw_createNormalizedVoxels version %.1f\n', version);


    voxels = [];        % return empty list if failure
    
    % get mni coordinates in RAS

    % note bounding box in any direction may not divide evenly so will drop
    % last value SPM truncates (works best for voxelSize = 5 mm
    % get number of voxels for each dimension and add one voxel for zero.
    nx = round( (boundingBox(4) - boundingBox(1)) / mmPerVoxel ) + 1;
    ny = round( (boundingBox(5) - boundingBox(2)) / mmPerVoxel ) + 1;
    nz = round( (boundingBox(6) - boundingBox(3)) / mmPerVoxel ) + 1;
    X = linspace(boundingBox(1), boundingBox(4),nx);  % ust linspace to force number of voxels to match
    Y = linspace(boundingBox(2), boundingBox(5),ny);  
    Z = linspace(boundingBox(3), boundingBox(6),nz);

    nvoxels = nx * ny * nz;
    fprintf('Warping %d voxels to MNI space ...\n', nvoxels);

    % fast method to build array of coordinates for 3D uniform grid
    % this syntax results in X slowest changing coordinate and Z 
    % the fastest changing coordinate
    [Y,X,Z] = meshgrid(Y,X,Z);
    mni_coords = [X(:),Y(:),Z(:)];

    % warp MNI coordinates to MEG (head based) coordinates 
    % should return coordinates in head coordinates in CM
    fprintf('warping mni grid to MEG coordinates...\n')
    temp = [mni_coords, ones(size(mni_coords,1), 1) ];
    meg_coords = temp * mni2meg;  % transform to mni coordinates and scale to cm
    meg_coords(:,4) = [];
  
    voxels = meg_coords;
end

