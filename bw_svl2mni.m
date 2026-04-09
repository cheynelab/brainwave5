function [niftiFile] = bw_svl2mni(svlFile, MNI_to_MEG)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_svl2mni(svlFile)
%
%  test function to normalize .svl images using affine transformation from
%  Freesurfer or CIVET
%   
%
%  (c) D. Cheyne, 2025. All rights reserved. 
%  This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

version = 3.4;
fprintf('bw_svl2mni version %.1f\n\n', version);

MNI_BB = [-78 -112 -50 78 76 85];

% read in the passed .svl file header and data

fid = fopen(svlFile, 'r', 'b','latin1');

%%  read .svl header
identity = transpose(fread(fid,8,'*char'));
if(~strcmp(identity,'SAMIMAGE'))
    error('This doesn''t look like a SAM IMAGE file.');
end % if SAM image
vers = fread(fid,1,'int32'); % SAM file version
setname = fread(fid,256,'*char');
numchans = fread(fid,1,'int32');
numweights = fread(fid,1,'int32');
if(numweights ~= 0)
    warning('... numweights ~= 0');
end

padbytes1 = fread(fid,1,'int32');

XStart = fread(fid,1,'double');
XEnd = fread(fid,1,'double');
YStart = fread(fid,1,'double');
YEnd = fread(fid,1,'double');
ZStart = fread(fid,1,'double');
ZEnd = fread(fid,1,'double');
StepSize = fread(fid,1,'double');

hpFreq = fread(fid,1,'double');
lpFreq = fread(fid,1,'double');
bwFreq = fread(fid,1,'double');
meanNoise = fread(fid,1,'double');

MRIname = transpose(fread(fid,256,'*char'));
nasion = fread(fid,3,'int32');
rightPA = fread(fid,3,'int32');
leftPA = fread(fid,3,'int32');

SAMtype = fread(fid,1,'int32');
SAMunit = fread(fid,1,'int32');
 
padbytes2 = fread(fid,1,'int32');

if ( vers > 1 )
    nasion_meg = fread(fid,3,'double');
    rightPA_meg = fread(fid,3,'double');
    leftPA_meg = fread(fid,3,'double');
    SAMunitname = fread(fid,32,'*char');
end % version 2 has extra fields

SAMimage = fread(fid,inf,'double'); % 1-d array of voxel values

fclose(fid);

% scale svl coordinates from meters to cm (transform expects MEG in cm)

StepSize = StepSize * 100.0;
XStart = XStart * 100.0;
XEnd = XEnd * 100.0;
YStart = YStart * 100.0;
YEnd = YEnd * 100.0;
ZStart = ZStart * 100.0;
ZEnd = ZEnd * 100.0;

%  .svl file is a stack of coronal slices
nx = size(XStart:StepSize:XEnd,2); % posterior -> anterior (coronal) 
ny = size(YStart:StepSize:YEnd,2); % right -> left (saggital)
nz = size(ZStart:StepSize:ZEnd,2); % bottom -> top (axial)

% transpose svl data into RAS
% Img = reshape(SAMimage, nz, ny, nx); % reshape 1-d array to 3-d
% Img = permute(Img, [2 3 1]); % Analyze format
% Img = flipdim(Img, 1); % left -> right

Img = reshape(SAMimage, nx, ny, nz); % reshape 1-d array to 3-d
% Img = permute(Img, [2 3 1]); % Analyze format
% Img = flipdim(Img, 1); % left -> right


% get meg coordinates in RAS
X = XStart:StepSize:XEnd;
Y = YStart:StepSize:YEnd;
Z = ZStart:StepSize:ZEnd;

% fast method to build array of coordinates for uniform grid
% this syntax results in X slowest changing coordinate and Z 
% the fastest changing coordinate
[Y, Z, X] = meshgrid(Y,Z,X);
meg_coords = [X(:), Y(:), Z(:)];

% warp MEG (.svl) coordinates to MNI coordinates. 
fprintf('warping points...\n')
meg2mni = inv(MNI_to_MEG);
temp = [meg_coords, ones(size(meg_coords,1), 1) ];
mni_coords = temp * meg2mni;  % transform to mni coordinates and scale to cm
mni_coords(:,4) = [];

% interpolate meg onto regular default MNI grid in mm

% fast method to build array of coordinates for uniform grid
% this syntax results in X slowest changing coordinate and Z 
% the fastest changing coordinate
voxelSize = StepSize * 10.0;

% method used by SPM?
% get number of voxels for each dimension and add one voxel for zero.
nx = round( (MNI_BB(4) - MNI_BB(1)) / voxelSize ) + 1;
ny = round( (MNI_BB(5) - MNI_BB(2)) / voxelSize ) + 1;
nz = round( (MNI_BB(6) - MNI_BB(3)) / voxelSize ) + 1;
xcoords = linspace(MNI_BB(1), MNI_BB(4),nx);  % ust linspace to force number of voxels to match
ycoords = linspace(MNI_BB(2), MNI_BB(5),ny);  
zcoords = linspace(MNI_BB(3), MNI_BB(6),nz);  


% this syntax makes coordinate list with z fastest changing, x slowest
% changing parameter
% [Y, Z, X] = meshgrid(ycoords,zcoords, xcoords);
% mni_grid_coords = [X(:), Y(:), Z(:)];

v = Img(:);  % pass image data as single vector
% F = scatteredInterpolant(mni_coords,v);

% newImg = F(mni_grid_coords);
% 
fprintf('interpolating ...\n')
F = scatteredInterpolant(mni_coords,v);
[x, y, z] = meshgrid(xcoords,ycoords,zcoords);
newImg = F(x,y,z);
newImg = permute(newImg,[2,1,3]);       % need to flip x and y here???
fprintf('...done\n')

% *** test code **
% pass 3D data to make_nii
% Img(:) = 0.0;
% Img(1, 1, 1) = 10.0;
% Img(20, 24, 18) = 10.0;
% Img = reshape(newImg, nx, ny, nz);

% create a default MNI NIfTI image in RAS coordinates
% **************************************


mniFile = strrep(svlFile,'.svl','.nii');
[p,n,e] = fileparts(mniFile);
n = strcat('w',n);
mniFile = fullfile(p,[n e]);

dims = size(newImg);

MNI_ORIGIN = [MNI_BB(1) MNI_BB(2) MNI_BB(3)];

% compute voxel origin from corner of bounding box 
xo = abs((MNI_BB(1) / voxelSize) ) + 1; % add one for zero, don't round
yo = abs((MNI_BB(2) / voxelSize) ) + 1;  % add one for zero, don't round
zo = abs((MNI_BB(3) / voxelSize) ) + 1; % add one for zero, don't round
VOXEL_ORIGIN = [xo yo zo];


% 

% 
% Img = ones(dims) * 3.0;
% Img(1,1,1) =  14.0;
% Img(end-1,end-1,end-1) =  14.0;
% 
% Img(21,29,14) =  14.0;
% ImgSize = size(Img)

% put in LAS format
% Img = flipdim(Img, 1); % left -> right

nii = make_nii(newImg, voxelSize, VOXEL_ORIGIN, dataType);

nii.hdr.dime.pixdim = [1 voxelSize voxelSize voxelSize 1 1 1 1];
nii.hdr.dime.vox_offset = 352; % not set?
nii.hdr.hist.sform_code = 1;
nii.hdr.hist.srow_x = [voxelSize 0 0 MNI_BB(1)];
nii.hdr.hist.srow_y = [0 voxelSize 0 MNI_BB(2)];
nii.hdr.hist.srow_z = [0 0 voxelSize MNI_BB(3)];
nii.hdr.hist.originator = VOXEL_ORIGIN;
nii.hdr.hist.descrip = 'BrainWave MNI normalized';
nii.hdr.hist.qoffset_x = MNI_BB(1);
nii.hdr.hist.qoffset_y = MNI_BB(2);
nii.hdr.hist.qoffset_z = MNI_BB(3);

% 

save_nii(nii, mniFile);


return

