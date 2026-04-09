% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %  
% Stand-alone script to convert one or more MNI voxels to CTF (MEG)
% coordinates based on an SPM normalization file created with BrainWave
% 
% D. Cheyne, Feb3, 2022
% 
% input:
% tmat              4 x 4 affine transformation from MNI to MEG coords        
% mni_coords:       n x 3 array of mni coordinates to convert (in mm)
% verbose:          set to false to run in silent mode
%
% returns:          n x 3 array of CTF coordinates in cm 
% % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % % %  

function meg_coords = bw_mni2meg(mni2meg, mni_coords, verbose)

    meg_coords = [];
    
    if size(mni_coords,2) ~= 3
        fprintf('Input must be n x 3 array of MNI coordinates in mm\n');
        return;
    end
    
    if ~exist('verbose','var')
        verbose = 1;
    end
    
    numCoords = size(mni_coords,1);

    if verbose
        fprintf('bw_mni2meg:\nConverting MNI coordinates to MEG ...\n');
    end

    coords = [mni_coords ones(numCoords)];
    
    meg_coords = coords * mni2meg;
    meg_coords(:,4) = [];

    if verbose
        for j=1:numCoords
            fprintf('%g %g %g (MNI) --> %g %g %g (CTF)\n', mni_coords(j,:),meg_coords(j,:));
        end
    end
           
end