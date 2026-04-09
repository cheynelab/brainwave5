%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read a .sfp file - format consistent with NDI Polaris system 
% function [na_ctf, le_ctf, re_ctf, shapePoints] = bw_readSFPFile(shapeFileName)
%
% returns all coordinates in cm
%
% D. Cheyne, June, 2025
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [shape_points, na_ctf, le_ctf, re_ctf] = bw_readSFPFile(shapeFileName)
    sfp = importdata(shapeFileName);
    
    % fids in .sfp file fids not in same coordinates as CTF
    % Also, these all lie on orthogonal axes so are
    % not same as CTF fiducials?

    idx = find(strcmp((sfp.rowheaders), 'FidNz'));
    if isempty(idx)
        fprintf('Could not find FidNz fiducial in sfp file\n');
        return;
    end
    na_sfp = sfp.data(idx,:);

    idx = find(strcmp((sfp.rowheaders), 'FidT9'));
    if isempty(idx)
        fprintf('Could not find FidT9 fiducial in sfp file\n');
        return;
    end
    le_sfp = sfp.data(idx,:);    
    idx = find(strcmp((sfp.rowheaders), 'FidT10'));
    if isempty(idx)
        fprintf('Could not find FidT10 fiducial in sfp file\n');
        return;
    end
    re_sfp = sfp.data(idx,:);
    
    pts = sfp.data;
    npts = size(pts,1);

    % seem to still need to put points into CTF frame of reference using fiducials??? 
    shape2ctf = bw_getAffineVox2CTF(na_sfp, le_sfp, re_sfp, 1.0);
    shape_points = [pts ones(npts,1)] * shape2ctf;
    shape_points(:,4) = [];
    na_ctf = [na_sfp 1] * shape2ctf;
    le_ctf = [le_sfp 1] * shape2ctf;
    re_ctf = [re_sfp 1] * shape2ctf;
    na_ctf(4) = [];
    le_ctf(4) = [];
    re_ctf(4) = [];

    fprintf('Read fiducials (na = %.3f %.3f %.3f cm, le = %.3f %.3f %.3f cm, re = %.3f %.3f %.3f cm) and %d shape points\n',...
        na_ctf, le_ctf, re_ctf, npts);               

end
