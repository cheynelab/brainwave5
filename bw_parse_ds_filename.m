%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(fullname)
%
%   [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(fullname)
%
%   DESCRIPTION: From a dataset name will identify and return (separately) 
%   the names and paths of the dataset, the corresponding MRI and the 
%   subject's ID.
%
%   Feb 2012 - modified to look for .nii file, then .mri
%
% (c) D. Cheyne, 2011. All rights reserved. 
%
%   Updatad and simplified code Nov, 2025 
% 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(fullname)
    ds_path = [];
    ds_name = [];
    subject_ID = [];

    mri_path = [];
    mri_filename = [];
    
    a = strfind(fullname, filesep);
    
    if isempty(a)
        ds_path = [];
        dirPath = [];
        ds_name = fullname;
    else
        ds_path = fullname(1:a(end)-1);
        dirPath = strcat(ds_path, filesep);       
        ds_name = fullname(a(end)+1:end);
    end

    % subjectID is everything before the first underscore
    a = strfind(ds_name,'_');     
    subject_ID = ds_name(1:a(1)-1);
    
    % look for MRI file for this dataset 
    
    mriDIR = sprintf('%s%s_MRI%',dirPath,subject_ID);
    mriNAME = sprintf('%s.nii',subject_ID);
    mri_filename = strcat(mriDIR,filesep,mriNAME);

    if ~isempty(mri_filename)
        a = strfind(mri_filename,filesep);
        mri_path = mri_filename(1:a(end)-1);
    end
    
end