%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_writeHeadCoilFile(dsName, fid_pts_standard, fid_pts_head, fid_pts_dewar)
%
%   function bw_writeHeadCoilFile(dsName, fid_pts_standard, fid_pts_head, fid_pts_dewar)
%
%   updated Nov, 2025 for converting FIFF files..
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_writeHeadCoilFile(dsName, fid_pts_standard, fid_pts_head, fid_pts_dewar)

na_standard = fid_pts_standard.na;      % default head position if no co-reg
le_standard = fid_pts_standard.le;
re_standard = fid_pts_standard.re;

na_dewar = fid_pts_dewar.na;        % fiducials in device coordinates
le_dewar = fid_pts_dewar.le;
re_dewar = fid_pts_dewar.re;

na_head = fid_pts_head.na;          % fiducials in head coordinates
le_head = fid_pts_head.le;
re_head = fid_pts_head.re;


[~, name, ~] = bw_fileparts(dsName);
hcname = sprintf('%s.hc',name);
filename = fullfile(dsName,hcname);

fp = fopen(filename,'w');
if (fp == -1)
    fprintf('failed to open file %s',filename);
    return;
end

fprintf('Writing head coil file to %s ...\n', dsName)

% default head position
fprintf(fp, 'standard nasion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', na_standard(1));
fprintf(fp, '\ty = %.5f\n', na_standard(2));
fprintf(fp, '\tz = %.5f\n', na_standard(3));	
fprintf(fp, 'standard left ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', le_standard(1));
fprintf(fp, '\ty = %.5f\n', le_standard(2));
fprintf(fp, '\tz = %.5f\n', le_standard(3));	
fprintf(fp, 'standard right ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', re_standard(1));
fprintf(fp, '\ty = %.5f\n', re_standard(2));
fprintf(fp, '\tz = %.5f\n', re_standard(3));
fprintf(fp, 'standard inion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	
fprintf(fp, 'standard Cz coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	

fprintf(fp, 'measured nasion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', na_dewar(1));
fprintf(fp, '\ty = %.5f\n', na_dewar(2));
fprintf(fp, '\tz = %.5f\n', na_dewar(3));	
fprintf(fp, 'measured left ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', le_dewar(1));
fprintf(fp, '\ty = %.5f\n', le_dewar(2));
fprintf(fp, '\tz = %.5f\n', le_dewar(3));
fprintf(fp, 'measured right ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', re_dewar(1));
fprintf(fp, '\ty = %.5f\n', re_dewar(2));
fprintf(fp, '\tz = %.5f\n', re_dewar(3));
fprintf(fp, 'measured inion coil position relative to dewar (cm):\n');  
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	
fprintf(fp, 'measured Cz coil position relative to dewar (cm):\n');		
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	

fprintf(fp, 'measured nasion coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', na_head(1));
fprintf(fp, '\ty = %.5f\n', na_head(2));
fprintf(fp, '\tz = %.5f\n', na_head(3));
fprintf(fp, 'measured left ear coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', le_head(1));
fprintf(fp, '\ty = %.5f\n', le_head(2));
fprintf(fp, '\tz = %.5f\n', le_head(3));
fprintf(fp, 'measured3 right ear coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', re_head(1));
fprintf(fp, '\ty = %.5f\n', re_head(2));
fprintf(fp, '\tz = %.5f\n', re_head(3));
fprintf(fp, 'measured3 inion coil position relative to head (cm):\n'); 
fprintf(fp, '\tx = 0.0\n');
fprintf(fp, '\ty = 0.0\n');
fprintf(fp, '\tz = 0.0\n');
fprintf(fp, 'measured3 Cz coil position relative to head (cm):\n');
fprintf(fp, '\tx = 0.0\n');
fprintf(fp, '\ty = 0.0\n');
fprintf(fp, '\tz = 0.0\n');

fclose(fp);

end