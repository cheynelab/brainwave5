function [s1 s2 s3 s4 s5 range] = bw_get_tal_label(tal_coords, searchRadius)
%       BW_GET_TAL_LABEL
%
%   function [s1 s2 s3 s4 s5 range] = bw_get_tal_label(tal_coords, searchRadius)
%
%   DESCRIPTION: Using the tatairach_data.mat file the function finds the
%   Talairach labels (s1-s5) for the Talairach coordinates specified by
%   tal_coords within the specified search radius (searchRadius) as well as 
%   indicating how far away the nearest gray matter was (range).
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%   --VERSION 2.2--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Edited help file.
%
% Revised by N.v.L. on 17/05/2010
% Major Changes: Edited help file.
%
% Revised by D. Cheyne on 18/08/2008
% Major Changes: incorrect range checking fixed
%
% Written by D. Cheyne on --/08/2008 for the Hospital for Sick Children

s1 = 'out of range';
s2 = 'out of range';
s3 = 'out of range';
s4 = 'out of range';
s5 = 'out of range';
range = searchRadius;

load ('talairach_data.mat');

% subtract SPM origin get passed coordinates relative corner of image (0,0,0)
x = tal_coords(1) + talairach_data.origin(1);
y = tal_coords(2) + talairach_data.origin(2);
z = tal_coords(3) + talairach_data.origin(3);

% abort if voxel is outside of the volume
if (x < 1 || x > size(talairach_data.volume,1)); return; end
if (y < 1 || y > size(talairach_data.volume,2)); return; end
if (z < 1 || z > size(talairach_data.volume,3)); return; end    

% else set default to center voxel
vox_idx = talairach_data.volume(x,y,z);

% search in increasing  radius from the center voxel until we find a gray
% matter voxel or exceed the passed search radius
%


% Version 5.0 new search method that searches in increasing perimeters from center instead
% of previous which would search in full searchRadius in z direction for
% each step in y (then increment x) 

% lastVoxels = [0 0 0];
% method = 1
% tic
% for k=0:searchRadius
% 
%     [xx,yy,zz] = meshgrid(x-k:x+k, y-k:y+k, z-k:z+k );
%     voxels = [xx(:),yy(:),zz(:)];
%     % only search outermost voxels 
% 
%     % get indices of previous volume and removed them
%     idxx = find(ismember(voxels,lastVoxels,'rows'));
%     perimeter = voxels;
%     perimeter(idxx,:) = [];
%     lastVoxels = voxels;
% 
%     for j=1:size(perimeter,1)
%         xx = perimeter(j,1);
%         yy = perimeter(j,2);
%         zz = perimeter(j,3);
%         if (xx < 1 || xx > size(talairach_data.volume,1)); continue; end
%         if (yy < 1 || yy > size(talairach_data.volume,2)); continue; end
%         if (zz < 1 || zz > size(talairach_data.volume,3)); continue; end    
% 
%         idx = talairach_data.volume(xx,yy,zz);
%         full_label = talairach_data.labels(idx+1,:);
%         foundGM = contains(full_label,'Gray Matter');
%         % fprintf('%d %d %s is gray %d\n',k, j, full_label, foundGM);
%         % at this point all voxels are equidistant from origin so take
%         % first in list
%         if foundGM
%             range = k;             
%             vox_idx = idx;                  
%             break;
%         end
%     end
%     if foundGM 
%         break;
%     end
% end
% toc

foundGM = false;
lastVoxels = [0 0 0];
xbound = size(talairach_data.volume,1);
ybound = size(talairach_data.volume,2);
zbound = size(talairach_data.volume,3);

for k=0:searchRadius

    [xx,yy,zz] = meshgrid(x-k:x+k, y-k:y+k, z-k:z+k );
    voxels = [xx(:),yy(:),zz(:)];
    % only search outermost voxels 

    % get indices of previous volume and remove those voxels from search
    idxx = find(ismember(voxels,lastVoxels,'rows'));
    perimeter = voxels;
    perimeter(idxx,:) = [];
    lastVoxels = voxels;

    for j=1:size(perimeter,1)
        xx = perimeter(j,1);
        yy = perimeter(j,2);
        zz = perimeter(j,3);
        if (xx < 1 || xx > xbound); continue; end
        if (yy < 1 || yy > ybound); continue; end
        if (zz < 1 || zz > zbound); continue; end    

        idx = talairach_data.volume(xx,yy,zz);
        full_label = talairach_data.labels(idx+1,:);
        dots = strfind(full_label,'.');             
        s3 = full_label(dots(3)+1:dots(4)-1); 
        foundGM = contains(s3,'Gray Matter');
        
        % at this point all voxels are equidistant from source so take
        % first in list
        if foundGM          
            range = norm( [x y z] - [xx yy zz]);       
            vox_idx = idx;   
            break;
        end
    end
    if foundGM 
        break;
    end
end

% tic
% method = 1
% foundGM = false;
% 
% for sr=0:searchRadius   
%     for xx= x-sr:x+sr
%         for yy= y-sr:y+sr           
%             for zz=z-sr:z+sr   
%                 % get index into label list
%                 if (xx < 1 || xx > xbound); continue; end
%                 if (yy < 1 || yy > ybound); continue; end
%                 if (zz < 1 || zz > zbound); continue; end 
%                 idx = talairach_data.volume(xx,yy,zz);                 
%                 full_label = talairach_data.labels(idx+1,:);
%                 dots = strfind(full_label,'.');             
%                 s3 = full_label(dots(3)+1:dots(4)-1);
% 
%                 if strcmp(s3,'Gray Matter')                      
%                     range = norm( [x y z] - [xx yy zz])           
%                     vox_idx = idx;                  
%                     foundGM = true;   
% 
%                     full_label = talairach_data.labels(vox_idx+1,:)
%                 end        
% 
%                 if foundGM; break; end
%             end
%             if foundGM; break; end
%         end
%         if foundGM; break; end
%     end
%     if foundGM; break; end
% end
% 
% toc

full_label = talairach_data.labels(vox_idx+1,:);
dots = strfind(full_label,'.');             
s1 = full_label(1:dots(1)-1);
s2 = full_label(dots(1)+1:dots(2)-1);    
s3 = full_label(dots(2)+1:dots(3)-1); 
s4 = full_label(dots(3)+1:dots(4)-1); 
s5 = full_label(dots(4)+1:end); 

