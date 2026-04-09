function params = bw_set_image_options(dsName, input_params)
%       BW_SET_IMAGE_OPTIONS
%
%   function params.beamformer_params = bw_set_image_options(bf,param)
%
%   DESCRIPTION: Creates a GUI that allows the user to set a series of
%   parameters related to creating beamformer images.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%
%   --VERSION 1.1--
% Last Revised by N.v.L. on 13/07/2010
% Major Changes: Uicontrols were shifted around and new options of
% makeBeamformer added such as voxgrid, nofix, output, mean, etc. 
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Changed the help file.
%
% Written by N.v.L. on 03/06/2010 for the Hospital for Sick Children.

%% FIGURE

global BW_PATH;

stepSizeNames={'10 mm';'8 mm';'5 mm';'4 mm';'3 mm';'2.5 mm';'2 mm'};
stepSizeVals=[1.0 0.8 0.5 0.4 0.3 0.25 0.2];

% currently not editable 
MNI_BB = [-78 -112 -50 78 76 86];


outputFormatNames={'Plain Text file (.txt)';'Freesurfer Overlay (.w)'};

% get paths to this subject's MRI directory

[ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);        

scrnsizes=get(0,'MonitorPosition');

f=figure('Name', 'Image Options', 'Position', [scrnsizes(1,3)/3 scrnsizes(1,4)/2 900 500],...
            'menubar','none','numbertitle','off', 'Color','white');

params = input_params;        
        
        
%SAVES THE BEAMFORMERparameters
uicontrol('style','pushbutton','units','normalized','Position',[0.7 0.1 0.15 0.1],'String','Save',...
              'fontsize',10,'FontWeight','b',...
              'ForegroundColor','blue','Callback','uiresume(gcbf)','callback',@save_callBack);
 
    function save_callBack(~,~)     
        uiresume(gcbf);
    end
          
uicontrol('style','pushbutton','units','normalized','Position',[0.5 0.1 0.15 0.1],'String','Cancel',...
              'fontsize',10,'ForegroundColor','black','callback',@cancel_callBack);
              
    function cancel_callBack(~,~)
        params = input_params; % undo changes
        uiresume(gcf);
    end


% INITIALIZE VARIABLES

    % SVL BOUNDING BOX
uicontrol('style','text','units','normalized','position',[0.05 0.905 0.25 0.06],...
    'string','Bounding Box (MEG Coordinates)','fontweight','b','fontsize',10,'backgroundcolor','white','foregroundcolor','blue');
annotation('rectangle',[0.02 0.5 0.4 0.45],'edgecolor','blue');

% X
uicontrol('style','text','units','normalized','position',[0.07 0.845 0.12 0.06],...
    'string','X Min (cm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.785 0.12 0.06],...
    'string','X Max (cm):','fontsize',10, 'backgroundcolor','white');

BB_X_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.86 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(1),'fontsize',10,'backgroundcolor','white','callback',@bb_x_min_edit_callback);

    function bb_x_min_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))
        else
            params.beamformer_parameters.boundingBox(1)=str2double(string_value);
        end
    end

BB_X_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.8 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(2),'fontsize',10,'backgroundcolor','white','callback',@bb_x_max_edit_callback);
    function bb_x_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))
        else
            params.beamformer_parameters.boundingBox(2)=str2double(string_value);
        end
    end

% Y
uicontrol('style','text','units','normalized','position',[0.07 0.715 0.12 0.06],...
    'string','Y Min (cm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.655 0.12 0.06],...
    'string','Y Max (cm):','fontsize',10, 'backgroundcolor','white');
BB_Y_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.73 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(3),'fontsize',10,'backgroundcolor','white','callback',@bb_y_min_edit_callback);
    function bb_y_min_edit_callback(src,~)
     string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))                
        else
            params.beamformer_parameters.boundingBox(3)=str2double(string_value);
        end
    end
BB_Y_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.67 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(4),'fontsize',10,'backgroundcolor','white','callback',@bb_y_max_edit_callback);
    function bb_y_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
        else
            params.beamformer_parameters.boundingBox(4)=str2double(string_value);
        end
    end
% Z
uicontrol('style','text','units','normalized','position',[0.07 0.585 0.12 0.06],...
    'string','Z Min (cm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.525 0.12 0.06],...
    'string','Z Max (cm):','fontsize',10, 'backgroundcolor','white');
BB_Z_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.6 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(5),'fontsize',10,'backgroundcolor','white','callback',@bb_z_min_edit_callback);
    function bb_z_min_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
              
        else
            params.beamformer_parameters.boundingBox(5)=str2double(string_value);
        end
    end
BB_Z_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.54 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(6),'fontsize',10,'backgroundcolor','white','callback',@bb_z_max_edit_callback);
    function bb_z_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
        else
            params.beamformer_parameters.boundingBox(6)=str2double(string_value);
        end
    end


% make MNI BB variable ??? 

uicontrol('style','text','units','normalized','position',[0.05 0.41 0.25 0.06],...
    'string','Bounding Box (MNI Coordinates)','fontweight','b','fontsize',10,'backgroundcolor','white','foregroundcolor','blue');
annotation('rectangle',[0.02 0.03 0.4 0.42],'edgecolor','blue');

% X

uicontrol('style','text','units','normalized','position',[0.07 0.34 0.12 0.06],...
    'string','X Min (mm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.28 0.12 0.06],...
    'string','X Max (mm):','fontsize',10, 'backgroundcolor','white');

MNI_X_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.365 0.1 0.06],...
    'string',MNI_BB(1),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_x_min_edit_callback);

    function MNI_x_min_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(1)=str2double(string_value);
    end

MNI_X_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.3 0.1 0.06],...
    'string',MNI_BB(4),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_x_max_edit_callback);
    function MNI_x_max_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(4)=str2double(string_value);
    end

% Y
uicontrol('style','text','units','normalized','position',[0.07 0.21 0.12 0.06],...
    'string','Y Min (cm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.15 0.12 0.06],...
    'string','Y Max (cm):','fontsize',10, 'backgroundcolor','white');
MNI_Y_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.235 0.1 0.06],...
    'string',MNI_BB(2),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_y_min_edit_callback);
    function MNI_y_min_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(2)=str2double(string_value);
    end
MNI_Y_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.17 0.1 0.06],...
    'string',MNI_BB(5),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_y_max_edit_callback);
    function MNI_y_max_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(5)=str2double(string_value);
    end
% Z
uicontrol('style','text','units','normalized','position',[0.07 0.09 0.12 0.06],...
    'string','Z Min (cm):','fontsize',10,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.03 0.12 0.06],...
    'string','Z Max (cm):','fontsize',10, 'backgroundcolor','white');
MNI_Z_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.105 0.1 0.06],...
    'string',MNI_BB(3),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_z_min_edit_callback);
    function MNI_z_min_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(3)=str2double(string_value);
    end
MNI_Z_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.04 0.1 0.06],...
    'string',MNI_BB(6),'fontsize',10,'enable','off','backgroundcolor','white','callback',@MNI_z_max_edit_callback);
    function MNI_z_max_edit_callback(src,~)
        string_value=get(src,'string');
        MNI_BB(6)=str2double(string_value);
    end

% image options

init_val = find(stepSizeVals==params.beamformer_parameters.stepSize);
        
uicontrol('style','text','units','normalized','position',[0.46 0.83 0.15 0.06],...
     'string','Voxel Size:','fontweight','b','fontsize',10,'backgroundcolor','white','foregroundcolor','blue','horizontalAlignment','left');

 uicontrol('style','popup','units','normalized',...
    'position',[0.55 0.8 0.15 0.1],'String',stepSizeNames,'Backgroundcolor','white','fontsize',10,...
    'value',init_val,'callback',@stepsize_popup_callback);

        function stepsize_popup_callback(src,~)
            menu_select=get(src,'value');
            params.beamformer_parameters.stepSize = stepSizeVals(menu_select);           
        end

NOISE_Z_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.46 0.745 0.2 0.06],...
    'value',1,'string','Pseudo-Z Normalization','fontsize',10,'backgroundcolor','white','callback',@noise_z_radio_callback);
    function noise_z_radio_callback(~,~)
        set(NOISE_Z_RADIO,'value',1);
    end

noisefT = params.beamformer_parameters.noise*1e15;

uicontrol('style','text','units','normalized','HorizontalAlignment','Left','position',[0.7 0.73 0.1 0.06],...
        'String','RMS:','fontsize',10,'BackGroundColor','white','foregroundcolor','black');
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.82 0.73 0.1 0.06],...
        'String','fT / sqrt(Hz)','fontsize',10,'BackGroundColor','white','foregroundcolor','black');
NOISE_EDIT=uicontrol('style','edit','units','normalized','position', [0.75 0.75 0.05 0.06],...
        'String',noisefT , 'FontSize', 12, 'BackGroundColor','white','callback',@noise_edit_callback);
    function noise_edit_callback(src,~)
        s=get(src,'String');
        if isempty(s)
            params.beamformer_parameters.noise=3.0e-15;
            set(NOISE_EDIT,'string',3.0)
        else
            params.beamformer_parameters.noise=str2double(s)*1e-15;   % convert from fT to Tesla
        end
    end


uicontrol('style','check', 'units', 'normalized','position',[0.46 0.64 0.2 0.06],...
        'String','Apply Brain Mask', 'BackGroundColor','white','fontsize',10,'Value', params.beamformer_parameters.useBrainMask,'callback',@useMask_check_callback);
MASK_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.63 0.64 0.08 0.06],...
    'enable','off','string','Select','foregroundcolor','blue','callback',@MASK_BUTTON_CALLBACK);

s = sprintf('Mask File: %s', params.beamformer_parameters.brainMaskFile);
MASK_LABEL = uicontrol('style','text','units','normalized','position',[0.46 0.56 0.3 0.06],'horizontalalignment','left',...
    'enable','off','string',s,'fontsize',10,'backgroundcolor','white');

if params.beamformer_parameters.useBrainMask
    set(MASK_BUTTON,'enable','on');
end      

function useMask_check_callback(src,~)
   params.beamformer_parameters.useBrainMask=get(src,'Value');

   if params.beamformer_parameters.useBrainMask
        set(MASK_LABEL,'enable','on');
        set(MASK_BUTTON,'enable','on');
   else
        set(MASK_LABEL,'enable','off');
        set(MASK_BUTTON,'enable','off');
   end 

end

function MASK_BUTTON_CALLBACK(~,~)
    
     [ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);
     defPath = strcat(mriDir,filesep,'*.nii');
     
     [name,~,~] = uigetfile({'*.nii'},'Select Binary Mask',defPath);
     if isequal(name,0)
        return;
     end
     params.beamformer_parameters.brainMaskFile = name;
     s = sprintf('Mask File: %s',name);
     set(MASK_LABEL,'string',s);

end

if params.beamformer_parameters.useBrainMask
    set(MASK_LABEL,'enable','on');
    set(MASK_BUTTON,'enable','on');
else
    set(MASK_LABEL,'enable','off');
    set(MASK_BUTTON,'enable','off');
end 

    
uicontrol('style','text','units','normalized','position',[0.46 0.905 0.2 0.06],...
    'string','Image Options','fontweight','b','fontsize',10,'backgroundcolor','white','foregroundcolor','blue');
annotation('rectangle',[0.44 0.35 0.5 0.6],'edgecolor','blue');


uicontrol('style','check', 'units', 'normalized','position',[0.46 0.4 0.3 0.05],...
        'String','Use normal constraint for surfaces', 'BackGroundColor','white','FontSize', 10,'Value', params.beamformer_parameters.useVoxNormals,'callback',@useNormal_check_callback);
    function useNormal_check_callback(src,~)
       params.beamformer_parameters.useVoxNormals=get(src,'Value');
    end


% moved from Data Parameters menu
% only one normalization method currently - could add here variance normalization etc...


%% RESUMING MATLAB
 uiwait(gcf);
%% CLOSING FIGURE
  if ishandle(f)
    close(f);  
  end     
end