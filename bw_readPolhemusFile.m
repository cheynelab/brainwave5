    function [headshape, NASION, LPA, RPA] = bw_readPolhemusFile (filename)

        % function to read Polemus data from various file formats
        % written by D. Cheyne and M. Woodbury

        % returns fiducials if available and head surface points in cm 

        headshape = [];
        NASION = [];
        LPA = [];
        RPA = [];
        
        fid = fopen(filename);
        if fid == -1
            error('Unable to open shape file.');
        end

        A = textscan(fid,'%s%s%s%s');
        fclose(fid);

        headshape = [str2double(A{2}(2:end)) str2double(A{3}(2:end)) str2double(A{4}(2:end))];

        idx = find(strcmp((A{1}), 'nasion') | strcmp((A{1}), 'Nasion'));
        if isempty(idx)
            fprintf('Could not find nasion fiducial in pos file\n');
            return;
        end
                   
        NASION = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))];
        if size(NASION,1) > 1     % average if multiple instances
            NASION = mean(NASION,1);
        end
            
        idx = find(strcmp((A{1}), 'left') | strcmp((A{1}), 'LPA'));
        if isempty(idx)
            fprintf('Could not find left fiducial in pos file\n');
            return;
        end
        LPA = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))];
        if size(LPA,1) > 1     % average if multiple instances
            LPA = mean(LPA,1);
        end
        
        idx = find(strcmp((A{1}), 'right') | strcmp((A{1}), 'RPA'));
        if isempty(idx)
            fprintf('Could not find right fiducial in pos file\n');
            return;
        end
        RPA = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))];
        if size(RPA,1) > 1     % average if multiple instances
            RPA = mean(RPA,1);
        end

    end