%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_makeSensorPosFile(dsName, saveName, dewarCoordinates, scale_cm)
% 
%   create a .pos file from the primary sensor locations
%   if scale_cm passed scale sensors in direction of their orientation
%
%   D. Cheyne Nov, 2025
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bw_makeSensorPosFile(dsName, saveName, dewarCoordinates, scale_cm)

    if ~exist('dewarCoordinates','var')
        dewarCoordinates = 0;
    end

    [coords, orientations] = bw_getSensorCoordinates(dsName, dewarCoordinates);
    
    npts = size(coords,1);

    % if scale passed - scale positions in direction of orientation vector
    % negative scale is towards origin / head
    if exist('scale_cm','var')
        for k=1:npts
            pos = coords(k,:);
            ori = orientations(k,:);
            coords(k,:) = pos + (ori * -scale_cm);
        end 
    end


    fid = fopen(saveName,'w','a');

    fprintf(fid, '%d\n',npts);
    for k=1:npts
        fprintf(fid, '%d   %.3f  %.3f   %.3f\n', k, coords(k,:));
    end

    % defaults
    Nasion = [8 0 0];
    LPA = [0 7.5 0];
    RPA = [0 -7.5 0];


    fprintf(fid, 'Nasion   %.3f   %.3f   %.3f\n', Nasion);
    fprintf(fid, 'LPA   %.3f   %.3f   %.3f\n', LPA);
    fprintf(fid, 'RPA   %.3f   %.3f   %.3f\n', RPA);

    fclose(fid);

end