function imageList = bw_make_beamformer(dsName, covDsName, params)
%
%   old calling syntax 
%
%   function [listFile fileName] = bw_make_beamformer(dsName, startLatency, endLatency, params, displaycheck)
%
%   DESCRIPTION: Generates an ERB or a pseudo Z single state beaformer 
%   or T or F differential beamformer image with the list file of images 
%   (fileName) and the name of the listFile returned (listFile).  
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   --VERSION 2.1--
% Last Revised by N.v.L. on 13/07/2010
% Major Changes: Is updated to include the new makeBeamformer features such
% as nofix, mean, and output format.
%
% Revised by N.v.L. on 07/07/2010
% Major Changes: Now passes the name of the MRI file.
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Cleaned up the function and edited the help file.
%
%
% Revised by N.v.L. on 21/05/2010
% Major Changes: Added the "dsname" parameter when it passes to
% bw_mip_plot_4D so that it can plot virtual sensors.
%
% Revised by N.v.L. on 17/05/2010
% Major Changes: Changed help file.
%
% Written by D. Cheyne on --/05/2010 for the Hospital for Sick Children


imageList = [];  % return null list on failure

% check parameters common to all image types before calling mex functions...... 

% check write permission for the .ds folder
isWriteable = bw_isWriteable(dsName);
if ~isWriteable
    return;
end

% check data range for covariance file
covHeader = bw_CTFGetHeader(covDsName);
ctfmin = covHeader.epochMinTime;
ctfmax = covHeader.epochMaxTime;
clear covHeader

dsHeader = bw_CTFGetHeader(dsName);
dsmin = dsHeader.epochMinTime;
dsmax = dsHeader.epochMaxTime;
clear dsHeader
        
% if needed make local copies of head model and voxfile names with full path
if (params.useHdmFile)
    params.hdmFile = fullfile(dsName, params.hdmFile);
    if ~exist(params.hdmFile,'file')
        fprintf('Head model file %s does not exist\n', params.hdmFile);
        return;
    end
end

% ** sanity check that booleans are always passed as int ....


if params.useReverseFilter
    bidirectional = 1;
else
    bidirectional = 0;
end

if ~params.useRegularization
    regularization = 0.0;
else
    regularization = params.regularization;
end

if ~params.filterData 
    params.filter(1) = 0.0;
    params.filter(2) = 0.0;
end

% check that covariance window has been set correctly
if (params.covWindow(1) == 0.0 && params.covWindow(2) == 0.0) | params.covWindow(2) < params.covWindow(1)
    fprintf('Covariance window settings are invalid (%f to %f seconds)\n',params.covWindow);
    return;
end

if (params.covWindow(1) < ctfmin || params.covWindow(2) > ctfmax)
    fprintf('Covariance window settings (%f to %f seconds) are outside of data range (%f to %f seconds)\n',params.covWindow, ctfmin,ctfmax);
    return;
end

if params.multiDsSAM
   useCovAsControl = 1;
else
   useCovAsControl = 0;
end

if params.useVoxFile
    if ~exist(params.voxFile,'file')
        fprintf('Vox file %s not found\n', params.voxFile);
        return;
    end
    useVoxFile = 1;
else
    useVoxFile = 0;
    params.voxFile = ' ';    
end

if params.useVoxNormals
    useNormals = 1;
else
    useNormals = 0;
end

tic

fprintf('\n******************************\n');
fprintf('Computing beamformer images ...\n');
fprintf('******************************\n');
switch params.beam.use
    case 'ERB'


        if (params.beam.latencyStart < dsmin || params.beam.latencyStart > dsmax...
            || params.beam.latencyEnd < dsmin || params.beam.latencyEnd > dsmax)
            fprintf('\n*** Latency range outside of dataset trial boundaries\n');
            return;
        end

        fprintf('Computing ERB beamformer images from %g to %g s (every %g s) from dataset %s\n',...
            params.beam.latencyStart, params.beam.latencyEnd, params.beam.step, dsName);
        fprintf('Using covariance dataset %s to compute beamformer weights\n',covDsName);

        % build latencyList from range and step...
        params.beam.latencyList = params.beam.latencyStart:params.beam.step:params.beam.latencyEnd'; % need row vector
        numLatencies = length(params.beam.latencyList);       
                        
        [~, imageList] = bw_makeEventRelated(dsName, covDsName, params.hdmFile,...
                   params.useHdmFile, params.filter, params.boundingBox, params.stepSize,... 
                   params.covWindow, params.voxFile, useVoxFile, useNormals,...
                   params.baseline, params.useBaselineWindow, params.sphere,...
                   params.noise, regularization, numLatencies,params.beam.latencyList,...
                   params.nr,params.rms, params.pm, params.mean, bidirectional, params.outputFormat);   
         samUnits = 3;
         
    case 'ERB_LIST'
        
        if isempty(params.beam.latencyList)
            fprintf('\n*** No latencies specified in list...\n');
            return;    
        end
        numLatencies = length(params.beam.latencyList);  
        
        latStart = min(params.beam.latencyList);
        latEnd = max(params.beam.latencyList);
        if (latStart < dsmin || latStart > dsmax || latEnd < dsmin || latEnd > dsmax)
            fprintf('\n*** Active window outside of trial boundaries\n');
            return;
        end            
        
        fprintf('Computing ERB beamformer for %d latencies  ...\n', numLatencies); 
        fprintf('Computing beamformer weights from dataset %s \n',covDsName);
        
        [~, imageList] = bw_makeEventRelated(dsName, covDsName, params.hdmFile,...
                   params.useHdmFile, params.filter, params.boundingBox, params.stepSize,... 
                   params.covWindow, params.voxFile, useVoxFile, useNormals,...
                   params.baseline, params.useBaselineWindow, params.sphere,...
                   params.noise, regularization, numLatencies,params.beam.latencyList,...
                   params.nr,params.rms, params.pm, params.mean, bidirectional, params.outputFormat);   
         samUnits = 3;
                
    case {'Z', 'T', 'F'}

        latEnd = params.beam.activeEnd + (params.beam.no_step * params.beam.active_step);  
        if (params.beam.activeStart < dsmin || params.beam.activeStart > dsmax || latEnd < dsmin || latEnd > dsmax)
            fprintf('\n*** Active window outside of trial boundaries\n');
            return;
        end    
        if useCovAsControl
            bmin = ctfmin;
            bmax = ctfmax;
        else
            bmin = dsmin;
            bmax = dsmax;
        end
        addlat=0;
        diffList={};
        latList={};
        
        fprintf('Computing differential beamformer images (no. steps = %d)...\n', params.beam.no_step);
        
        for n=1:params.beam.no_step + 1
            
            activeWindow=[params.beam.activeStart+addlat params.beam.activeEnd+addlat];
            baselineWindow=[params.beam.baselineStart params.beam.baselineEnd];
            
            if params.beam.use == 'Z'
                fprintf('Computing pseudo-Z images (active window = %g to %g s) from dataset %s\n',activeWindow, dsName);
                fprintf(' ** Using covariance dataset %s to compute beamformer weights **\n',covDsName);

                imageType = 1;
                samUnits = 3;
            elseif params.beam.use == 'T'

                if (params.beam.baselineStart < bmin || params.beam.baselineStart > bmax ||...
                    params.beam.baselineEnd < bmin || params.beam.baselineEnd > bmax)
                    fprintf('\n*** Baseline window outside of trial boundaries\n');
                    return;
                end
                fprintf('Computing pseudo-T images (active window (%g to %g s) minus baseline window (%g to %g s) from dataset %s\n',... 
                    activeWindow,baselineWindow, dsName);
                if useCovAsControl
                    fprintf(' ** Using covariance dataset %s to compute beamformer weights for baseline window **\n',covDsName);
                else
                    fprintf('Computing beamformer weights from dataset %s\n',covDsName);
                end
                imageType = 2;
                samUnits = 4;            
            elseif params.beam.use == 'F'
                if (params.beam.baselineStart < bmin || params.beam.baselineStart > bmax ||...
                    params.beam.baselineEnd < bmin || params.beam.baselineEnd > bmax)
                    fprintf('\n*** Baseline window outside of trial boundaries\n');
                    return;
                end
                fprintf('Computing pseudo-F images for active window (%g to %g s) divided by baseline window (%g to %g s) from dataset %s\n',... 
                    activeWindow, baselineWindow, dsName);
                if useCovAsControl
                    fprintf(' ** Using covariance dataset %s to compute beamformer weights for baseline window **\n',covDsName);
                else
                    fprintf('Computing beamformer weights from dataset %s\n',covDsName);
                end
                imageType = 3;
                samUnits = 5;            
            else
                fprintf('unknown beamformer option \n');
                return;
            end
        
            [imageList] = bw_makeDifferential(dsName, covDsName, params.hdmFile,...
            params.useHdmFile, params.filter, params.boundingBox,...
            params.stepSize,  params.voxFile, useVoxFile, useNormals, params.sphere, params.noise,...
            regularization, imageType, activeWindow, baselineWindow,...
            params.rms, bidirectional, useCovAsControl,  params.outputFormat); 
        
            diffList{n} = imageList(1,:);
            addlat=addlat+params.beam.active_step;
            
            fprintf('...done.\n\n');
        end    
        imageList = char(diffList);
        
end

if isempty(imageList)
    return;
end

toc


disp('Done generating images...')  

end