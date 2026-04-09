function bw_group_analysis (inputFile)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_group_analysis
%
%   DESCRIPTION: Creates a GUI that allows users to generate images from a
%   list of datasets for group averaging etc.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
% 
% updated Dec, 2015  D. Cheyne
%
% Version 4.0 March 2022 - removed surface based group imaging
% Version 5.3 March 2026 - 
%    - new file replaces bw_group_images.m 
%    - updated GUI moved beamformer parameter controls to main window 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


scrnsizes=get(0,'MonitorPosition');

global BW_VERSION

batchJobs.enabled = false;
batchJobs.numJobs = 0;
batchJobs.processes = {};

% get prefs from study structure instead...

% removed this since prefs saved with Study can be used instead

% prefs = bw_checkPrefs;
% params.beamformer_parameters =  prefs.beamformer_parameters;
% params.spm_options = prefs.params.spm_options;

% [params.beamformer_parameters, vs_options, tfr_options] = bw_setDefaultParameters;  
% *** bug fix in version 3.0beta release ***
params = bw_setDefaultParameters;

currentStudyFile = '';
currentStudyDir = '';
study = [];
study.no_conditions = 0;
condition1 = 1;
condition2 = 1;
covCondition= 1;
conditionType = 1;

selectedDataset = '';
selectedDatasetIndex = 1;

changes_saved = true;
displayResults = true;

useFullEpoch = 1;
usePreStim = 1;
dsParams = [];
covDsParams = [];

button_orange = [0.8,0.4,0.1];

f=figure('Name', 'BrainWave - Group Image Analysis', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  1250 800],...
            'menubar','none','numbertitle','off', 'Color','white','CloseRequestFcn',@QUIT_MENU_CALLBACK);
if ispc
    movegui(f,'center');
end
FILE_MENU=uimenu('Label','File');
uimenu(FILE_MENU,'label','Open Study...','Accelerator','O', 'Callback',@OPEN_STUDY_BUTTON_CALLBACK);
uimenu(FILE_MENU,'label','New Study...','Accelerator','N', 'Callback',@NEW_STUDY_BUTTON_CALLBACK);

SAVE_STUDY_BUTTON = uimenu(FILE_MENU,'label','Save Study','Accelerator','S',...
    'separator','on','Callback',@SAVE_STUDY_BUTTON_CALLBACK);
SAVE_STUDY_AS_BUTTON = uimenu(FILE_MENU,'label','Save Study As...','Callback',@SAVE_STUDY_AS_BUTTON_CALLBACK);

ADD_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Add Condition...','Accelerator','A','separator','on', 'Callback',@add_condition_callback);
REMOVE_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Remove Condition...','Accelerator','D', 'Callback',@remove_condition_callback);
COMBINE_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Combine Conditions...','Accelerator','C', 'Callback',@combine_condition_callback);
uimenu(FILE_MENU,'label','Copy Head Models...','Accelerator','H','separator','on', 'Callback',@copyHeadModels_callback);

uimenu(FILE_MENU,'label','Close','Callback',@QUIT_MENU_CALLBACK,'Accelerator','W','separator','on');

BATCH_MENU=uimenu('Label','Batch');
START_BATCH=uimenu(BATCH_MENU,'label','Open New Batch','Callback',@START_BATCH_CALLBACK);
STOP_BATCH=uimenu(BATCH_MENU,'label','Close Batch','Callback',@STOP_BATCH_CALLBACK);
RUN_BATCH=uimenu(BATCH_MENU,'label','Run Batch...','separator','on','Callback',@RUN_BATCH_CALLBACK); 

IMAGESETS_MENU=uimenu('Label','ImageSets');    
set(IMAGESETS_MENU,'enable','off');

% list option not available yet..
if strcmp(params.beamformer_parameters.beam.use, 'ERB_LIST')
    fprintf('group analysis does not support list mode .. setting to default range...\n');
    params.beamformer_parameters.beam.use = 'ERB';
end

uicontrol('style','text','units','normalized','position',...
    [0.02 0.925 0.1 0.05],'string','Select Condition:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','black','fontsize',12,'fontweight','bold');
CONDITION1_LISTBOX=uicontrol('style','listbox','units','normalized','position',...
    [0.02 0.62 0.19 0.32],'string','','fontsize',10,'background','white','callback',@condition1_callback);
CONDITION1_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.1 0.93 0.1 0.05],'string',{'None'},'background','white',...
    'foregroundcolor','blue','fontsize',11,'callback',@condition1_dropdown_callback);

uicontrol('style','checkbox','units','normalized','position',...
    [0.225 0.94 0.1 0.05],'string','Contrast with:','background','white','value',params.beamformer_parameters.contrastImage,...
    'fontsize',12,'fontweight','bold','callback',@contrast_check_callback);
CONDITION2_LISTBOX=uicontrol('style','listbox','units','normalized','enable','off','position',...
    [0.225 0.62 0.19 0.32],'string','','fontsize',10,'max',10000,'background','white','callback',@condition2_callback);
CONDITION2_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.31 0.93 0.1 0.05],'string',{'None'},'background','white','enable','off',...
    'foregroundcolor','blue','fontsize',11,'callback',@condition2_dropdown_callback);

uicontrol('style','text','units','normalized','position',...
    [0.43 0.925 0.1 0.05],'string','Covariance:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','black','fontsize',12,'fontweight','bold');
COV_LISTBOX=uicontrol('style','listbox','units','normalized','position',...
    [0.43 0.62 0.19 0.32],'string','','fontsize',10,'max',10000,'background','white','callback',@cov_callback);
COV_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.5 0.93 0.1 0.05],'string',{'None'},'background','white',...
    'foregroundcolor','blue','fontsize',11,'callback',@cov_dropdown_callback);

    function contrast_check_callback(src,~)
        val = get(src,'value');
        if val
            conditionType = 3;
            params.beamformer_parameters.contrastImage = 1;
            set(CONDITION2_DROP_DOWN,'enable','on');
            set(CONDITION2_LISTBOX,'enable','on');
        else
            conditionType = 1;
            params.beamformer_parameters.contrastImage = 0;
            set(useSAMBaselineCheck,'enable','on');
            set(CONDITION2_DROP_DOWN,'enable','off');
            set(CONDITION2_LISTBOX,'enable','off');
        end
        updateRadios;
    end

useSAMBaselineCheck = uicontrol('Style','checkbox','FontSize',12,'Units','Normalized','Position',...
    [0.225 0.58 0.2 0.04],'String','Use for SAM baseline','HorizontalAlignment','Center','enable','off',...
    'BackgroundColor','White','value',params.beamformer_parameters.multiDsSAM,'Callback',@MULTI_DS_SAM_CALLBACK);
    
    % ** change 4.2
    function MULTI_DS_SAM_CALLBACK(src,~)
       params.beamformer_parameters.multiDsSAM = get(src,'value');
       if params.beamformer_parameters.multiDsSAM
           warndlg('Select this option to use contrast dataset for SAM baseline window');                     
       end
    end


    DATASET_INFO_TEXT=uicontrol('style','text','Units','Normalized','fontsize',12,'Position',...
    [0.03 0.03 0.6 0.14],'String','Select Dataset...','BackgroundColor','White','HorizontalAlignment','left');

    function update_ds_text
               
        dsParams = bw_CTFGetHeader(selectedDataset);
        if ~isempty(dsParams)
            [p,n,e] = fileparts(selectedDataset);
            ds_info=sprintf('Path: %s\nDataset: %s\n\nAcquistion Parameters:\n%d sensors, %d trials, %d Samples/trial\nBandwidth: %g to %g Hz, %g Samples/s\nEpoch Duration: %g to %g s', ...
                p, [n e], dsParams.numSensors, dsParams.numTrials, dsParams.numSamples,...
                dsParams.highPass, dsParams.lowPass, dsParams.sampleRate, dsParams.epochMinTime, dsParams.epochMaxTime);               
            set(DATASET_INFO_TEXT,'string',ds_info);
        end
    end

ADD1_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.02 0.58 0.09 0.025],...
    'string','Add datasets','callback',@ADD1_BUTTON_CALLBACK);
DELETE1_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.12 0.58 0.09 0.026],...
    'string','Remove datasets','callback',@DELETE1_BUTTON_CALLBACK);

DATASET_NUM_TEXT = uicontrol('style','text','units','normalized','position',...
    [0.02 0.54 0.05 0.03],'string','(n = 0)','background','white','fontsize',12);

GENERATE_IMAGES_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',12,'fontweight','bold','position',...
    [0.65 0.1 0.2 0.07],'string','Generate Group Images',...
    'foregroundcolor',button_orange,'callback',@plot_images_callback);

if isunix && ~ismac
    set(ADD1_BUTTON,'Backgroundcolor','white');
    set(DELETE1_BUTTON,'Backgroundcolor','white');
    set(GENERATE_IMAGES_BUTTON,'Backgroundcolor','white');
end

uicontrol('Style','PushButton','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.02 0.14 0.05],'String','Image Options...','HorizontalAlignment','Center',...
    'Callback',@set_image_params_callback);

uicontrol('style','checkbox','units','normalized','position',...
   [0.82 0.02 0.12 0.05],'string','Display Results','fontsize',12,'value',displayResults,...
   'Backgroundcolor','white','callback',@display_results_callback);

% beamformer controls
uicontrol('style','text','units','normalized','position',...
    [0.03 0.51 0.12 0.03],'string','Latency / Time Windows','background','white','HorizontalAlignment','center',...
    'fontsize',11,'foregroundcolor','blue','fontweight','bold');
annotation('rectangle',[0.02 0.2 0.6 0.33],'EdgeColor','blue');

uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.03 0.44 0.2 0.03],'HorizontalAlignment','Left','String','ERB:','FontWeight','b','Background','White');

RADIO_ERB=uicontrol('style','radiobutton','units','normalized','position',...
    [0.07 0.44 0.1 0.03],'string','','backgroundcolor','white','callback',@RADIO_ERB_CALLBACK);

LATENCY_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.18 0.485 0.2 0.03],'HorizontalAlignment','Left','String','Latency Range (s):','Background','White');
LAT_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.18 0.43 0.05 0.04],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
START_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.22 0.44 0.05 0.04],'String',params.beamformer_parameters.beam.latencyStart,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK);

LAT_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.29 0.43 0.05 0.04],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
END_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.33 0.44 0.05 0.04],'String',params.beamformer_parameters.beam.latencyEnd,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK);

LAT_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.4 0.43 0.05 0.04],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
STEPSIZE_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.45 0.44 0.05 0.04],'String',params.beamformer_parameters.beam.step,'BackgroundColor',...
    'White','Callback',@PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK);


% SAM controls 
uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.03 0.31 0.05 0.04],'HorizontalAlignment','Left','String','SAM:','FontWeight','b','Background','White');

RADIO_Z=uicontrol('style','radiobutton','units','normalized','position',...
    [0.07 0.36 0.15 0.04],'string',' Pseudo-Z','backgroundcolor','white','callback',@RADIO_Z_CALLBACK);

RADIO_T=uicontrol('style','radiobutton','units','normalized','position',...
    [0.07 0.31 0.15 0.04],'string',' Pseudo-T','backgroundcolor','white','callback',@RADIO_T_CALLBACK);

RADIO_F=uicontrol('style','radiobutton','units','normalized','position',...
    [0.07 0.26 0.15 0.04],'string',' Pseudo-F','backgroundcolor','white','callback',@RADIO_F_CALLBACK);

ACTIVE_WINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.18 0.37 0.1 0.04],'HorizontalAlignment','Left','String','Active Window (s):','Background','White');
ACTIVE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.18 0.33 0.05 0.04],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
ACTIVE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.22 0.34 0.05 0.04],'String',params.beamformer_parameters.beam.activeStart,'BackgroundColor','White','Callback',...
    @ACTIVE_START_EDIT_CALLBACK);
ACTIVE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.29 0.33 0.05 0.04],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
ACTIVE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.33 0.34 0.05 0.04],'String',params.beamformer_parameters.beam.activeEnd,'BackgroundColor','White','Callback',...
    @ACTIVE_END_EDIT_CALLBACK);
ACTIVE_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.4 0.33 0.05 0.04],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
ACTIVE_STEP_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.45 0.34 0.05 0.04],'String',params.beamformer_parameters.beam.active_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_STEP_LAT_EDIT_CALLBACK);
ACTIVE_NO_STEP_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.5 0.33 0.05 0.04],'String','No. Steps:','BackgroundColor','White');
ACTIVE_NO_STEP_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.55 0.34 0.05 0.04],'String',params.beamformer_parameters.beam.no_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_NO_STEP_EDIT_CALLBACK);

BASELINE_WINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.18 0.28 0.1 0.04],'HorizontalAlignment','Left','String','Baseline Window (s):','Background','White');
BASELINE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.18 0.24 0.05 0.04],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
BASELINE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.22 0.25 0.05 0.04],'String',params.beamformer_parameters.beam.baselineStart,'BackgroundColor','White','Callback',...
    @BASELINE_START_EDIT_CALLBACK);
BASELINE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.29 0.24 0.05 0.04],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
BASELINE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.33 0.25 0.05 0.04],'String',params.beamformer_parameters.beam.baselineEnd,'BackgroundColor','White','Callback',...
    @BASELINE_END_EDIT_CALLBACK);


% beamformer param controls - replaces dialog

uicontrol('style','text','fontSize',11,'units','normalized','position',...
    [0.65 0.955 0.18 0.025],'string','Beamformer Parameters','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.635 0.2 0.35 0.77],'EdgeColor','blue');

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.915 0.25 0.04],...
        'String','Beamformer Type:','fontSize',10,'FontWeight','bold','BackGroundColor','white');

SCALAR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.65 0.89 0.15 0.04],...
    'value',~params.beamformer_parameters.rms,'string','Scalar','fontSize',10,'backgroundcolor','white','callback',@scalar_radio_callback);

VECTOR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.72 0.89 0.15 0.04],...
    'value',params.beamformer_parameters.rms,'string','Vector (LCMV)','fontSize',10,'backgroundcolor','white','callback',@vector_radio_callback);

    function scalar_radio_callback(src,~)
        set(src,'value',1);
        set(VECTOR_RADIO,'value',0);
        params.beamformer_parameters.rms = 0;
    end

    function vector_radio_callback(src,~)
        set(src,'value',1);
        set(SCALAR_RADIO,'value',0);
        params.beamformer_parameters.rms = 1;  
    end


% filter settings
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.825 0.2 0.04],...
        'String','Filter Bandpass (Hz):','fontSize',10,'FontWeight','bold','BackGroundColor','white');
    
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.78 0.1 0.04],...
        'String','Highpass:','fontSize',10,'BackGroundColor','white');

FILTER_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.72 0.79 0.04 0.035],...
        'String', params.beamformer_parameters.filter(1), 'FontSize', 9, 'BackGroundColor','white','callback',@filter_edit_min_callback);
    function filter_edit_min_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.filter(1) = 1;
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
            params.beamformer_parameters.filter(2) = 50;
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
        else
        params.beamformer_parameters.filter(1)=str2double(string_value);
        if params.beamformer_parameters.filter(1) < 0
            params.beamformer_parameters.filter(1) = 0;
        end
        if params.beamformer_parameters.filter(1) > dsParams.sampleRate / 2.0
            params.beamformer_parameters.filter(1)=dsParams.sampleRate / 2.0;
        end
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
        end
    end

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.78 0.78 0.1 0.04],...
        'String','Lowpass:','fontSize',10,'BackGroundColor','white');

FILTER_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.85 0.79 0.04 0.035],...
        'String',params.beamformer_parameters.filter(2), 'FontSize', 9, 'BackGroundColor','white','callback',@filter_edit_max_callback);
    function filter_edit_max_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.filter(2)=50;
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
            params.filter(1)=1;
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
        else
        params.beamformer_parameters.filter(2)=str2double(string_value);
        if params.beamformer_parameters.filter(2) > dsParams.sampleRate / 2
            params.beamformer_parameters.filter(2) = dsParams.sampleRate / 2;
        end
        if params.beamformer_parameters.filter(2) < 0
            params.beamformer_parameters.filter(2)=0;
        end
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
        end
    end

REVERSE_CHECK = uicontrol('style','checkbox','units','normalized','position',[0.91 0.79 0.07 0.04],...
        'String','zero phase','BackGroundColor','white','fontSize',10,'Value',...
        params.beamformer_parameters.useReverseFilter,'callback',@reverse_check_callback);
 
    function reverse_check_callback(src,~)
        params.beamformer_parameters.useReverseFilter=get(src,'Value');
    end

% set initial state
set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
set(REVERSE_CHECK,'value',params.beamformer_parameters.useReverseFilter)
 

% baseline window 
BASELINE_CORRECT_CHECK = uicontrol('style','checkbox','units','normalized','position',[0.65 0.74 0.18 0.04],...
        'String','Remove Offset (s)','BackGroundColor','white','fontSize',9,...
        'Value',params.beamformer_parameters.useBaselineWindow,'callback',@baseline_check_callback);
 
BASELINE_LABEL_MIN=uicontrol('style','text','units','normalized','position',[0.65 0.69 0.1 0.04],...
        'String','Start:','fontSize',10,'BackGroundColor','white','HorizontalAlignment','left');

BASELINE_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.68 0.7 0.05 0.035],...
        'String', params.beamformer_parameters.baseline(1), 'FontSize', 9, 'BackGroundColor','white','callback',@baseline_edit_min_callback);
    
    function baseline_edit_min_callback(src,~)
        string_value=get(src,'String');          
        params.beamformer_parameters.baseline(1) = str2double(string_value);
        if params.beamformer_parameters.baseline(1) < dsParams.epochMinTime || params.beamformer_parameters.baseline(1) > dsParams.epochMaxTime
            params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
            set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
        end   
    end

BASELINE_LABEL_MAX=uicontrol('style','text','units','normalized','position',[0.75 0.69 0.1 0.04],...
        'String','End:','fontSize',10,'BackGroundColor','white','HorizontalAlignment','left');
BASELINE_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.78 0.7 0.05 0.035],...
        'String', params.beamformer_parameters.baseline(2), 'FontSize', 9, 'BackGroundColor','white','callback',@baseline_edit_max_callback);
    function baseline_edit_max_callback(src,~)
        string_value=get(src,'String');          
        params.beamformer_parameters.baseline(2)=str2double(string_value);
        if params.beamformer_parameters.baseline(2) < dsParams.epochMinTime || params.beamformer_parameters.baseline(2) > dsParams.epochMaxTime
            params.beamformer_parameters.baseline(2) = dsParams.epochMaxTime;
            set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))
        end   
    end

BASELINE_USE_PRESTIM_CHECK=uicontrol('style','checkbox','units','normalized','position', [0.85 0.7 0.1 0.035],...
        'BackGroundColor','white','string', 'Use pre-stim', 'FontSize', 9, 'value',usePreStim, 'callback',@baseline_set_full_callback);

     function baseline_set_full_callback(src,~)
        usePreStim = get(src,'value');       
        params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
        params.beamformer_parameters.baseline(2) = 0.0;
        set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
        set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))    
        update_fields;
     end        

    function baseline_check_callback(src,~)
        val=get(src,'Value');
        if (val)
           params.beamformer_parameters.useBaselineWindow = 1;

           if params.beamformer_parameters.baseline(1) < dsParams.epochMinTime || params.beamformer_parameters.baseline(1) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
           end
           if params.beamformer_parameters.baseline(2) < dsParams.epochMinTime || params.beamformer_parameters.baseline(2) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(2) = 0.0;
           end     	    
           set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
           set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))
        else
            params.beamformer_parameters.useBaselineWindow = 0;     
        end
        update_fields;
    end



% data Parameters

% get data header values

function update_ds_params

   t = get(CONDITION1_LISTBOX,'string');
   dsName = char(t(1));
   if ~exist(dsName,'file')
       return;
   end

   t = get(COV_LISTBOX,'string');
   covDsName = char(t(1));
   if ~exist(covDsName,'file')
       return;
   end

   dsParams = bw_CTFGetHeader(dsName);
   covDsParams = bw_CTFGetHeader(covDsName);     % for cov window only
   
    if useFullEpoch
        params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
        set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
        params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
        set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
    end 

    if usePreStim       
       params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
       params.beamformer_parameters.baseline(2) = 0.0;
       set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
       set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))    
    end 

end




COV_TXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.61 0.2 0.04],...
        'String','ERB Covariance Window (s):','fontSize',10,'FontWeight','bold','BackGroundColor','white');

COV_LABEL_MIN = uicontrol('style','text','units','normalized','position',[0.65 0.56 0.1 0.04],'horizontalAlignment','left',...
    'String','Start:','fontSize',10,'BackGroundColor','white');

COV_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.68 0.57 0.05 0.035],...
    'String', params.beamformer_parameters.covWindow(1), 'FontSize', 9, 'BackGroundColor','white','callback',@cov_edit_min_callback);

COV_LABEL_MAX = uicontrol('style','text','units','normalized','position',[0.75 0.56 0.1 0.04],'horizontalAlignment','left',...
    'String','End:','fontSize',10,'BackGroundColor','white');

COV_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.78 0.57 0.05 0.035],...
    'String', params.beamformer_parameters.covWindow(2), 'FontSize', 9, 'BackGroundColor','white','callback',@cov_edit_max_callback);

COV_USE_FULL_CHECK = uicontrol('style','checkbox','units','normalized','position', [0.85 0.56 0.1 0.06],...
        'string', 'Use whole epoch', 'FontSize', 9,'value',useFullEpoch, ...
        'BackGroundColor','white','callback',@cov_set_full_callback);
    
    function cov_edit_min_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
        else
            params.beamformer_parameters.covWindow(1)=str2double(string_value);
            if params.beamformer_parameters.covWindow(1) > covDsParams.epochMaxTime
                params.beamformer_parameters.covWindow(1) = covDsParams.epochMaxTime;
            end
            if params.beamformer_parameters.covWindow(1) < covDsParams.epochMinTime
                params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            end
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
        end
    end

  
    function cov_edit_max_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
        else
            params.beamformer_parameters.covWindow(2)=str2double(string_value);
            if params.beamformer_parameters.covWindow(2) > covDsParams.epochMaxTime
                params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            end
            if params.beamformer_parameters.covWindow(2) < covDsParams.epochMinTime
                params.beamformer_parameters.covWindow(2) = covDsParams.epochMinTime;
            end
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))
        end
    end

     function cov_set_full_callback(src,~)
        useFullEpoch = get(src,'value');
        if useFullEpoch
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))    
            set(COV_EDIT_MIN,'enable', 'off');   
            set(COV_EDIT_MAX,'enable', 'off');   
            set(COV_LABEL_MIN,'enable', 'off');
            set(COV_LABEL_MAX,'enable', 'off');
        else
            set(COV_EDIT_MIN,'enable', 'on');
            set(COV_EDIT_MAX,'enable', 'on');                        
            set(COV_LABEL_MIN,'enable', 'on');
            set(COV_LABEL_MAX,'enable', 'on');
        end      
     end

    
% note params.regulalarization holds the power (in Telsa squared) to add to diagonal    
reg_fT = sqrt(params.beamformer_parameters.regularization) * 1e15;  %% convert to fT  RMS for edit box

REG_CHECK = uicontrol('style','checkbox','units','normalized','position',[0.65 0.51 0.25 0.04],'String','Apply diagonal regularization:',...
        'BackGroundColor','white','fontSize',10,'fontname','lucinda','Value',params.beamformer_parameters.useRegularization,'callback',@reg_check_callback);
    function reg_check_callback(src,~)
        val=get(src,'Value');
        if (val)
            params.beamformer_parameters.useRegularization=1;
            set(REG_EDIT,'enable','on')
        else
            params.beamformer_parameters.useRegularization=0;
            set(REG_EDIT,'enable','off')
        end
    end
     
REG_EDIT=uicontrol('style','edit','units','normalized','position', [0.81 0.51 0.05 0.035],...
        'String', reg_fT, 'FontSize', 9, 'BackGroundColor','white','callback',@reg_edit_callback);
    function reg_edit_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.regularization=0;
            set(REG_EDIT,'string',params.beamformer_parameters.regularization);
        else
            reg_fT = str2double(string_value);            
            params.beamformer_parameters.regularization = (reg_fT * 1e-15)^2; % convert from fT squared to Tesla squared 
        end
    end
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.87 0.5 0.1 0.04],...
        'String','fT / sqrt(Hz)','fontSize',10,'BackGroundColor','white');
 
% head model settings
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.43 0.25 0.04],...
        'String','Head Model:','fontSize',10,'FontWeight','bold','BackGroundColor','white');

HDM_RADIO = uicontrol('style','radio','units','normalized','position',[0.65 0.4 0.3 0.04],...
    'string','Use Head Model File (*.hdm):','fontSize',10,'Backgroundcolor','white',...
    'value',params.beamformer_parameters.useHdmFile,'callback',@hdm_radio_callback);
    
    function hdm_radio_callback (~,~)
        params.beamformer_parameters.useHdmFile = 1;

        set(HDM_EDIT,'enable','on');
        set(HDM_PUSH,'enable','on');
        set(SPHERE_RADIO,'value',0);
        set(HDM_RADIO,'value',1);
        set(SPHERE_EDIT_X,'enable','off');
        set(SPHERE_EDIT_Y,'enable','off');
        set(SPHERE_EDIT_Z,'enable','off');
        set(SPHERE_TITLE_X,'enable','off');
        set(SPHERE_TITLE_Y,'enable','off');
        set(SPHERE_TITLE_Z,'enable','off');

    end    
    
HDM_EDIT=uicontrol('style','edit','units','normalized','position', [0.65 0.36 0.18 0.04],...
        'String', params.beamformer_parameters.hdmFile, 'FontSize', 9, 'BackGroundColor','white','callback',@hdm_edit_callback);
    function hdm_edit_callback(src,~)
        params.beamformer_parameters.hdmFile =get(src,'String');
        if isempty(params.beamformer_parameters.hdmFile)
             params.beamformer_parameters.hdmFile='';
        end
    end

HDM_PUSH = uicontrol('style','pushbutton','units','normalized','position',[0.85 0.36 0.12 0.04],...
        'String','Load Head Model...','fontSize',9,'callback',@HDM_PUSH_CALLBACK);

    function HDM_PUSH_CALLBACK(~,~)
           
        t = get(CONDITION1_LISTBOX,'string');
        dsName = char(t(1));
        if ~exist(dsName,'file')
            return;
        end 

        s = fullfile(char(dsName),'*.hdm');
        [hdmfilename, hdmpathname, ~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if isequal(hdmfilename,0) || isequal(hdmpathname,0)
          return;
        end     

        params.beamformer_parameters.hdmFile = hdmfilename;
        set(HDM_EDIT,'string',hdmfilename)

    end

SPHERE_RADIO = uicontrol('style','radio','units','normalized','position',[0.65 0.32 0.3 0.04],...
    'string','Use Single Sphere Origin (cm):','fontSize',9,'Backgroundcolor','white',...
    'value',~params.beamformer_parameters.useHdmFile,'callback',@sphere_radio_callback);
    
    function sphere_radio_callback(~,~)
        params.beamformer_parameters.useHdmFile = 0;
        set(HDM_RADIO,'value',0);
        set(SPHERE_RADIO,'value',1);
        set(HDM_EDIT,'enable','off');
        set(HDM_PUSH,'enable','off');
        set(SPHERE_EDIT_X,'enable','on');
        set(SPHERE_EDIT_Y,'enable','on');
        set(SPHERE_EDIT_Z,'enable','on');
        set(SPHERE_TITLE_X,'enable','on');
        set(SPHERE_TITLE_Y,'enable','on');
        set(SPHERE_TITLE_Z,'enable','on');
        if isempty(params.beamformer_parameters.sphere)
            params.beamformer_parameters.sphere = [0 0 5];
        end
        set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
        set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
        set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
       
    end    
        
SPHERE_EDIT_X=uicontrol('style','edit','units','normalized','position', [0.68 0.28 0.05 0.035],...
        'String', params.beamformer_parameters.sphere(1), 'FontSize', 9, 'BackGroundColor','white','callback',@sphere_edit_x_callback);
    function sphere_edit_x_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.beamformer_parameters.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(1)=str2double(string_value);
        end
    end
    SPHERE_TITLE_X=uicontrol('style','text','units','normalized','position',[0.66 0.27 0.02 0.04],...
       'String','X:','fontSize',10,'BackGroundColor','white');
 
SPHERE_EDIT_Y=uicontrol('style','edit','units','normalized','position', [0.76 0.28 0.05 0.035],...
        'String', params.beamformer_parameters.sphere(2), 'FontSize', 9, 'BackGroundColor','white','callback',@sphere_edit_y_callback);
    function sphere_edit_y_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(2)=str2double(string_value);
        end
    end
SPHERE_TITLE_Y=uicontrol('style','text','units','normalized','position',[0.74 0.27 0.02 0.04],...
        'String','Y:','fontSize',10,'BackGroundColor','white');
       
SPHERE_EDIT_Z=uicontrol('style','edit','units','normalized','position', [0.84 0.28 0.05 0.035],...
        'String', params.beamformer_parameters.sphere(3), 'FontSize', 9, 'BackGroundColor','white','callback',@sphere_edit_z_callback);
    function sphere_edit_z_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.beamformer_parameters.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(3)=str2double(string_value);
        end
    end
    SPHERE_TITLE_Z=uicontrol('style','text','units','normalized','position',[0.82 0.27 0.02 0.04],...
        'String','Z:','fontSize',10,'BackGroundColor','white');
    


% call function if params changed. 
function update_fields
    
    if strcmp(params.beamformer_parameters.beam.use,'ERB') 
        
        set(RADIO_ERB, 'enable','on');

        if strcmp(params.beamformer_parameters.beam.use,'ERB')

            set(LAT_START_LABEL,'enable','on')
            set(LAT_END_LABEL,'enable','on') 
            set(ACTIVE_STEP_LAT_EDIT,'enable','on')
            set(LAT_STEPSIZE_LABEL,'enable','on')
            set(START_LAT_EDIT,'enable','on')
            set(START_LAT_EDIT,'string',params.beamformer_parameters.beam.latencyStart);
            set(END_LAT_EDIT,'enable','on')
            set(END_LAT_EDIT,'string',params.beamformer_parameters.beam.latencyEnd);
    
        end
          
        set(COV_TXT,'enable','on')
        if useFullEpoch
            set(COV_EDIT_MIN,'enable','off')
            set(COV_EDIT_MAX,'enable','off')
            set(COV_LABEL_MIN,'enable','off')
            set(COV_LABEL_MAX,'enable','off')     
        else
            set(COV_EDIT_MIN,'enable','on')
            set(COV_EDIT_MAX,'enable','on')
            set(COV_LABEL_MIN,'enable','on')
            set(COV_LABEL_MAX,'enable','on')     
        end                
        set(COV_USE_FULL_CHECK,'enable','on')               
        set(BASELINE_CORRECT_CHECK,'enable','on')
                  
        if params.beamformer_parameters.useBaselineWindow == 1
            set(BASELINE_USE_PRESTIM_CHECK,'enable','on')
            set(BASELINE_EDIT_MAX,'enable','on')
            set(BASELINE_EDIT_MIN,'enable','on')
            set(BASELINE_LABEL_MIN,'enable','on')
            set(BASELINE_LABEL_MAX,'enable','on')
        else
            set(BASELINE_USE_PRESTIM_CHECK,'enable','off')
            set(BASELINE_EDIT_MAX,'enable','off')
            set(BASELINE_EDIT_MIN,'enable','off')
            set(BASELINE_LABEL_MIN,'enable','off')
            set(BASELINE_LABEL_MAX,'enable','off')
        end
        if usePreStim
            set(BASELINE_EDIT_MAX,'enable','off')
            set(BASELINE_EDIT_MIN,'enable','off')
            set(BASELINE_LABEL_MIN,'enable','off')
            set(BASELINE_LABEL_MAX,'enable','off')
        else
            set(BASELINE_EDIT_MAX,'enable','on')
            set(BASELINE_EDIT_MIN,'enable','on')
            set(BASELINE_LABEL_MIN,'enable','on')
            set(BASELINE_LABEL_MAX,'enable','on')
        end              
        
        set_SAM_enable('off');

    else

        set(ACTIVE_STEP_LAT_EDIT,'enable','off')
        set(LAT_STEPSIZE_LABEL,'enable','off')
        set(START_LAT_EDIT,'enable','off')
        set(END_LAT_EDIT,'enable','off')
        set(LAT_START_LABEL,'enable','off')
        set(LAT_END_LABEL,'enable','off')     
        
        % version 5.0 - disable for SAM - less confusing 
        set(COV_TXT,'enable','off')
        set(COV_LABEL_MAX,'enable','off')
        set(COV_LABEL_MIN,'enable','off')
        set(COV_EDIT_MAX,'enable','off')
        set(COV_EDIT_MIN,'enable','off')
        set(COV_USE_FULL_CHECK,'enable','off')


        set(BASELINE_CORRECT_CHECK,'enable','off')
        set(BASELINE_USE_PRESTIM_CHECK,'enable','off')
        set(BASELINE_EDIT_MAX,'enable','off')
        set(BASELINE_EDIT_MIN,'enable','off')
        set(BASELINE_LABEL_MIN,'enable','off')
        set(BASELINE_LABEL_MAX,'enable','off')
                              
        % enable SAM fields
        set_SAM_enable('on');

        if strcmp(params.beamformer_parameters.beam.use,'Z')
            set(BASELINE_START_EDIT,'enable','off')
            set(BASELINE_START_LABEL,'enable','off')
            set(BASELINE_END_EDIT,'enable','off')
            set(BASELINE_END_LABEL,'enable','off')
        end                    
                 
        set(ACTIVE_START_EDIT,'string',params.beamformer_parameters.beam.activeStart);
        set(ACTIVE_END_EDIT,'string',params.beamformer_parameters.beam.activeEnd);
        set(BASELINE_START_EDIT,'string',params.beamformer_parameters.beam.baselineStart);
        set(BASELINE_END_EDIT,'string',params.beamformer_parameters.beam.baselineEnd);
        set(ACTIVE_STEP_LAT_EDIT,'string',params.beamformer_parameters.beam.active_step);
        set(ACTIVE_NO_STEP_EDIT,'string',params.beamformer_parameters.beam.no_step);
  
    end
       
    changes_saved = false;

end

function set_SAM_enable(str)
       
    %  SAM fields
    set(ACTIVE_WINDOW_LABEL,'enable',str)
    set(BASELINE_WINDOW_LABEL,'enable',str)
    set(BASELINE_START_EDIT,'enable',str)
    set(BASELINE_START_LABEL,'enable',str)
    set(BASELINE_END_EDIT,'enable',str)
    set(BASELINE_END_LABEL,'enable',str)
    set(ACTIVE_START_EDIT,'enable',str)
    set(ACTIVE_START_LABEL,'enable',str)
    set(ACTIVE_END_EDIT,'enable',str)
    set(ACTIVE_END_LABEL,'enable',str)
    set(ACTIVE_STEP_LAT_EDIT,'enable',str)
    set(ACTIVE_STEPSIZE_LABEL,'enable',str)
    set(ACTIVE_NO_STEP_LABEL,'enable',str)
    set(ACTIVE_NO_STEP_EDIT,'enable',str)   
end

function updateBeamformerParameters

    set(SCALAR_RADIO,'value',~params.beamformer_parameters.rms);
    set(VECTOR_RADIO,'value',params.beamformer_parameters.rms);
    
    set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
    set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
    set(REVERSE_CHECK,'value',params.beamformer_parameters.useReverseFilter);
    set(BASELINE_CORRECT_CHECK,'value',params.beamformer_parameters.useBaselineWindow);
    set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1));
    set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2));
  
    set(BASELINE_USE_PRESTIM_CHECK,'value',usePreStim);

    set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
    set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
    set(COV_USE_FULL_CHECK,'value',useFullEpoch);

    % note params.regularization holds the power (in Telsa squared) to add to diagonal    
    set(REG_CHECK,'value',params.beamformer_parameters.useRegularization);
    reg_fT = sqrt(params.beamformer_parameters.regularization) * 1e15;  %% convert to fT  RMS for edit box
    set(REG_EDIT,'string',reg_fT);
    
    if params.beamformer_parameters.useHdmFile == 1
        set(HDM_RADIO,'value',1);
        set(SPHERE_RADIO,'value',0);
        set(HDM_EDIT,'string',params.beamformer_parameters.hdmFile);
        set(HDM_EDIT,'enable','on');
        set(HDM_EDIT,'enable','on');
        set(HDM_PUSH,'enable','on');
        set(SPHERE_EDIT_X,'enable','off');
        set(SPHERE_EDIT_Y,'enable','off');
        set(SPHERE_EDIT_Z,'enable','off');
        set(SPHERE_TITLE_X,'enable','off');
        set(SPHERE_TITLE_Y,'enable','off');
        set(SPHERE_TITLE_Z,'enable','off'); 
    else
        set(SPHERE_RADIO,'value',1);
        set(HDM_RADIO,'value',0);
        set(HDM_EDIT,'enable','off');
        set(HDM_EDIT,'enable','off');
        set(HDM_PUSH,'enable','off');
        set(SPHERE_EDIT_X,'enable','on');
        set(SPHERE_EDIT_Y,'enable','on');
        set(SPHERE_EDIT_Z,'enable','on');
        set(SPHERE_TITLE_X,'enable','on');
        set(SPHERE_TITLE_Y,'enable','on');
        set(SPHERE_TITLE_Z,'enable','on');
        if isempty(params.beamformer_parameters.sphere)
            params.beamformer_parameters.sphere = [0 0 5];
        end
        set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
        set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
        set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));        
    end   


end



%%%  


set(STOP_BATCH,'enable','off')            
set(RUN_BATCH,'enable','off')            

set(SAVE_STUDY_BUTTON, 'enable','off');
set(SAVE_STUDY_AS_BUTTON, 'enable','off');
set(ADD_CONDITION_BUTTON, 'enable','off');
set(REMOVE_CONDITION_BUTTON, 'enable','off');
set(COMBINE_CONDITION_BUTTON, 'enable','off');

set(GENERATE_IMAGES_BUTTON,'enable','off')            

set(ADD1_BUTTON,'enable','off')            
set(DELETE1_BUTTON,'enable','off')            

% set initial state 
updateRadios;
update_fields;
updateBeamformerParameters;
    
changes_saved = true;   % suppress query

if exist(inputFile,'file')      
    open_Study(inputFile);
end

% =================================================

    function NEW_STUDY_BUTTON_CALLBACK(~,~)
       
        if changes_saved == false
            s = sprintf('Open new study without saving changes?');     
            response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end
        end
        
        [name, path,~] = uiputfile('new_STUDY.mat','Select Name for Study:','new_STUDY.mat');
        if isequal(name,0)
            return;
        end

        currentStudyFile = fullfile(path,name);
        currentStudyDir = path;
        cd(currentStudyDir);
        
        [~, studyName, ~] = fileparts(currentStudyFile);
        studyName = strrep(studyName,'_STUDY','');
        
        study.name = studyName;
        study.originalPath = currentStudyFile;
        study.conditions = [];
        study.conditionNames = [];
        study.no_conditions = 0;
        study.imagesets = [];
        
        prompt = {'Condition 1:','Condition 2:','Condition 3:','Condition 4:','Condition 5:',...
            'Condition 6:','Condition 7:','Condition 8:','Condition 9:','Condition 10'};
        title = 'Enter Labels for up to 10 Conditions ';
        dims = [1 100];
        definput = {'','','','','','','','','',''};
        input = inputdlg(prompt,title,dims,definput);
        
        for k=1:size(input,1)
            name = char(input{k});
            if ~isempty(name)
                study.no_conditions = study.no_conditions + 1;
                study.conditionNames{k} = name;
                study.conditions{k} = [];  % datasets for this condition
            end
        end
        
        % use current parameters
        params = bw_setDefaultParameters;     
        study.params = params;
        study.version = BW_VERSION;

        set(CONDITION1_DROP_DOWN, 'string',study.conditionNames);
        set(CONDITION1_LISTBOX, 'string','');
        set(CONDITION2_DROP_DOWN, 'string',study.conditionNames);
        set(CONDITION2_LISTBOX, 'string','');
        set(CONDITION2_LISTBOX, 'string','');
        set(COV_DROP_DOWN,'string',study.conditionNames); 
        set(COV_LISTBOX, 'string','');
        
        save(currentStudyFile, '-struct', 'study');
        set(SAVE_STUDY_BUTTON,'enable','on');
        set(SAVE_STUDY_AS_BUTTON,'enable','on');
        set(ADD_CONDITION_BUTTON, 'enable','on');
        set(REMOVE_CONDITION_BUTTON, 'enable','on');
        set(COMBINE_CONDITION_BUTTON, 'enable','on');
        set(CONDITION1_DROP_DOWN, 'enable','on');
        set(CONDITION1_LISTBOX, 'enable','on');            
     
        
        set(GENERATE_IMAGES_BUTTON,'enable','on')            
        set(ADD1_BUTTON,'enable','on')            
        set(DELETE1_BUTTON,'enable','on')     
        
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
        covCondition= 1;
        conditionType = 1;
        
        updateRadios
        s = sprintf('(n = 0)');       
        set(DATASET_NUM_TEXT,'string',s);          
    end

    function ADD1_BUTTON_CALLBACK(~,~)
         if isempty(study)
            return;
         end
        
        [s, ~, ~] = fileparts( currentStudyFile );       
        dsList = uigetdir2(s, 'Choose datasets for this condition...');
        
        if ~isempty(dsList) 
            s = cellfun(@removeFilePath, dsList,'UniformOutput',false);
            cond = get(CONDITION1_DROP_DOWN,'value');
            dsNames = study.conditions{cond};
            dsNames = [dsNames s];
            dsNames = sort(dsNames);
            study.conditions{cond} = dsNames;
            set(CONDITION1_LISTBOX,'string',dsNames );    
            changes_saved = false;
        end
       
        s = sprintf('(n = %d)',numel(dsNames));       
        set(DATASET_NUM_TEXT,'string',s);
    end

    function DELETE1_BUTTON_CALLBACK(~,~)
        if isempty(study)
            return;
        end
        if isempty(CONDITION1_LISTBOX)
            return;
        end
        selectedRow = get(CONDITION1_LISTBOX,'value');
        cond = get(CONDITION1_DROP_DOWN,'value');
        dsNames = study.conditions{cond};
        
        s = sprintf('Delete dataset [%s] from this condition?', char(dsNames(selectedRow)) );     
        response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
        if strcmp(response,'Cancel')
            return;
        end
        dsNames(selectedRow) = [];
        study.conditions{cond} = dsNames;
        set(CONDITION1_LISTBOX,'string',  dsNames );    
        set(CONDITION1_LISTBOX,'value',  1 );    
        changes_saved = false;

        s = sprintf('(n = %d)',numel(dsNames));       
        set(DATASET_NUM_TEXT,'string',s);     
   end

    function SAVE_STUDY_BUTTON_CALLBACK(~,~)     
        if isempty(study)
            return;
        end
        save_changes;       
    end

   function SAVE_STUDY_AS_BUTTON_CALLBACK(~,~)
       
        [name,path,~] = uiputfile('new_STUDY.mat','Select Name for Study:', currentStudyFile);
        if isequal(name,0)
            return;
        end
        currentStudyFile = fullfile(path,name);
       
        fprintf('Saving study information to %s\n', currentStudyFile);
        save_changes;        

        [~, studyName, ~] = fileparts(currentStudyFile);
        studyName = strrep(studyName,'_STUDY','');       
        study.name = studyName;
              
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
   end

   function save_changes
        study.params = params;
        
        % new fields
        study.usePreStim = usePreStim;
        study.useFullEpoch   = useFullEpoch;
        
        fprintf('Saving study information to %s\n', currentStudyFile);
        save(currentStudyFile, '-struct', 'study');
        changes_saved = true;       
   end


   function OPEN_STUDY_BUTTON_CALLBACK(~,~)
       
       if changes_saved == false
            response = questdlg('Open new study without saving changes?','BrainWave','Yes','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end                
       end
       
       [name, path, ~]=uigetfile({'*_STUDY.mat', 'GROUP STUDY (*_STUDY.mat)'},'Select a STUDY');
        if isequal(name,0)
            return;
        end
        
        filename = fullfile(path,name);
        
        open_Study(filename);
               
   end

   function open_Study(studyFileFull)
        
        currentStudyFile = studyFileFull;
        [currentStudyDir, ~, ~] = fileparts(studyFileFull);
        
        study = load(currentStudyFile);
        
        response = questdlg('Load the previously saved settings?','BrainWave','Use Previous','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end                 
        
        if strcmp(response,'Use Previous') 
            params = study.params;       
        else
            params = bw_setDefaultParameters;
        end
            
        % overwrite defaults - always use cov or baseline lists
        params.beamformer_parameters.multiDsSAM = 0;
        params.beamformer_parameters.covarianceType = 2;
        
        if isfield(study,'usePreStim')
            usePreStim = study.usePreStim;
        end
        if isfield(study,'useFullEpoch')
            useFullEpoch = study.useFullEpoch;
        end

        
        set(SAVE_STUDY_BUTTON,'enable','on');
        set(SAVE_STUDY_AS_BUTTON,'enable','on');
        set(ADD_CONDITION_BUTTON, 'enable','on');
        set(REMOVE_CONDITION_BUTTON, 'enable','on');
        set(COMBINE_CONDITION_BUTTON, 'enable','on');
        set(CONDITION1_DROP_DOWN, 'enable','on');
        set(CONDITION1_LISTBOX, 'enable','on');        
        
        % initiale to first condition....
        set(CONDITION1_DROP_DOWN,'string',study.conditionNames);
        set(CONDITION2_DROP_DOWN,'string',study.conditionNames);
        set(COV_DROP_DOWN,'string',study.conditionNames); 
        
        % new - CWD to path of list file in case of relative file paths
        %
        cd(currentStudyDir)
        fprintf('setting current working directory to %s\n',currentStudyDir);
               
        condition1 = 1;      
        set(CONDITION1_DROP_DOWN,'value',condition1 );   
        dsNames = study.conditions{condition1};
        
        set(COV_DROP_DOWN,'value',condition1 );    
        set(CONDITION2_DROP_DOWN,'value',condition1);   
                  
        % update list boxes unless datasets haven't been added yet
        if ~isempty(dsNames)
            set(CONDITION1_LISTBOX,'string',dsNames );
            set(COV_LISTBOX,'string',dsNames );      
            set(CONDITION2_LISTBOX,'string',dsNames );
            s = sprintf('(n = %d)',numel(dsNames));       
            set(DATASET_NUM_TEXT,'string',s);   
            selectedDatasetIndex = 1;
            selectedDataset = fullfile(char(currentStudyDir), char(dsNames(selectedDatasetIndex)) );
        end
                        
        set(GENERATE_IMAGES_BUTTON,'enable','on')            
         
        set(ADD1_BUTTON,'enable','on')            
        set(DELETE1_BUTTON,'enable','on')            
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
         
        % reset radios to default
        covCondition= 1;
        conditionType = 1;

        update_ds_params;   % get ds paramateres for time windows etc.

        % update GUI
        updateRadios;
        updateImageListMenu;
        update_fields;
        updateBeamformerParameters;

        changes_saved = true;
   end

    function remove_condition_callback(~,~)
     
        [condName, condIdx, ~] = bw_getConditionList('Select Condition to delete', currentStudyFile);
        
        if isempty(condName)
            return;
        end
        study.conditions(condIdx) = [];
        study.conditionNames(condIdx) = [];
        study.no_conditions = study.no_conditions - 1;
        changes_saved = false;

        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);                
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);  
        save_changes;       
                       
    end

    function add_condition_callback(~,~)
               
        [s, ~, ~] = fileparts( currentStudyFile );
        if isempty(s)
            return;
        end
        
        dsList = uigetdir2(s, 'Choose datasets for this condition...');
        if isempty(dsList)
            return;
        end
        
        for k=1:size(dsList,2)
            s = char(dsList{k});
            [~, dsNames{k}, ext] = fileparts(s);
            dsNames{k} = strcat(dsNames{k}, ext);
        end

        conditionName = getConditionName();
        
        if isempty(conditionName)
            return;
        end     
        
        study.no_conditions = study.no_conditions + 1;
        
        study.conditions{study.no_conditions} = dsNames;
        study.conditionNames{study.no_conditions} = conditionName;
        
        set(CONDITION1_LISTBOX,'string',study.conditions{study.no_conditions} );
        set(CONDITION1_LISTBOX,'value',1);
        selectedDatasetIndex = 1;
        selectedDataset = fullfile(char(currentStudyDir), char(dsNames(selectedDatasetIndex)) );

        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);            
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);              
        set(CONDITION1_DROP_DOWN,'value', study.no_conditions);      
        
        set(GENERATE_IMAGES_BUTTON,'enable','on')        
        changes_saved = false;

        
    end

    function combine_condition_callback(~,~)
                      
        response = questdlg('Combine two conditions?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end  
        
        [condName1, condIdx1, ~] = bw_getConditionList('Select Condition 1 ...', currentStudyFile);
        [~, condIdx2, ~] = bw_getConditionList('Select Condition 2 ...', currentStudyFile);
        
        if isempty(condName1)
            return;
        end
        
        conditionName = getConditionName();
        
        if isempty(conditionName)
            return;
        end
        
        % combine Datasets  

        dsList1 =  study.conditions{condIdx1};
        dsList2 =  study.conditions{condIdx2};  

        for j=1:size(dsList1,2)
            dsName1  = deblank( dsList1{1,j} );
            [~, name1, ~] = fileparts(dsName1);
            idx = strfind(name1,'_');
            subject_ID1 = name1(1:idx-1);
            basename1 = name1(idx+1:end);

            dsName2  = deblank( dsList2{1,j} );
            [~, name2, ~] = fileparts(dsName2);
            idx = strfind(name2,'_');
            subject_ID2 = name2(1:idx-1);
            basename2 = name2(idx+1:end);
            
            if strcmp(subject_ID1,subject_ID2) == 0
                errordlg('Subject ID does not match ... check condition lists');
                return;
            end
            combinedDsName = sprintf('%s_%s+%s.ds', subject_ID1,basename1,basename2);
            
            % check if combined ds exists already
            if exist(combinedDsName) == 7
                s = sprintf('dataset %s already exists...', combinedDsName);
                errordlg(s);
                return;
            else
                fprintf('***********************************************************************************\n');
                fprintf('creating combined dataset --> %s for for common weights covariance calculation...\n\n', combinedDsName);
                bw_combineDs({dsName1, dsName2}, combinedDsName);
                % D. Cheyne 3.4 copy any head models from the first
                % dataset to the combined dataset, assuming these are always same subject. 
                bw_copyHeadModels(dsName1,combinedDsName);
            end  
            dsNames{j} = combinedDsName;
            
        end
                       
        study.no_conditions = study.no_conditions + 1;
        
        study.conditions{study.no_conditions} = dsNames;
        study.conditionNames{study.no_conditions} = conditionName;
        
        set(CONDITION1_LISTBOX,'string',study.conditions{study.no_conditions} );
        set(CONDITION1_LISTBOX,'value',1);
        
        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);            
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);  
    
        changes_saved = false;                   
    end

    function copyHeadModels_callback(~,~)
        
        response = questdlg('Copy Head Models from one condition to another?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
        
        [condName1, condIdx1, ~] = bw_getConditionList('Select Condition to copy head models from...', currentStudyFile);
        [~, condIdx2, ~] = bw_getConditionList('Select Condition to copy head models to ...', currentStudyFile);
        
        if isempty(condName1)
            return;
        end

        dsList1 =  study.conditions{condIdx1};
        dsList2 =  study.conditions{condIdx2};  
        
        if size(dsList1,2) ~= size(dsList2,2)
            beep
            errordlg('Conditions contain different numbers of subjects...');
            return;
        end

        for j=1:size(dsList1,2)
            dsName1  = deblank( dsList1{1,j} );
            [~, ~, subject_ID1, ~, ~] = bw_parse_ds_filename(dsName1);
            dsName2  = deblank( dsList2{1,j} );
            [~, ~, subject_ID2, ~, ~] = bw_parse_ds_filename(dsName2);
            if strcmp(subject_ID1,subject_ID2) == 1
                fprintf('Copying head models from %s to %s...\n', dsName1, dsName2);
                bw_copyHeadModels(dsName1, dsName2);
            else
                errordlg('Subject ID does not match. Head models not copied');
            end
        end
                       
        
    end

    function condition1_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        condition1 = get(src,'value');
        if isempty(study.conditions{condition1})
            set(CONDITION1_LISTBOX,'string', '');  
            s = sprintf('n = 0');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{condition1};
        set(CONDITION1_LISTBOX,'string', names);  
        set(CONDITION1_LISTBOX,'value',1);
        selectedDatasetIndex = 1;
        dsName = names(selectedDatasetIndex(1));
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
              
        s = sprintf('(n = %d)',numel(names));       
        set(DATASET_NUM_TEXT,'string',s);
    end

    function condition1_callback(src,~)
        names = get(src,'string');
        selectedDatasetIndex = get(src,'value');
        dsName = names(selectedDatasetIndex);
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
        update_ds_text;
    end

    function condition2_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        condition2 = get(src,'value');
        if isempty(study.conditions{condition2})
            set(CONDITION2_LISTBOX,'string', '');  
            s = sprintf('(n = 0)');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{condition2};
        set(CONDITION2_LISTBOX,'string', names);  
        set(CONDITION2_LISTBOX,'value',1);
    end

    function condition2_callback(src,~)
        names = get(src,'string');
        selectedDatasetIndex = get(src,'value');
        dsName = names(selectedDatasetIndex(1));
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
        update_ds_text;
    end

   function cov_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        covCondition = get(src,'value');     
        if isempty(study.conditions{covCondition})
            set(COV_LISTBOX,'string', '');  
            s = sprintf('(n = 0)');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{covCondition};
        set(COV_LISTBOX,'string', names);  
        set(COV_LISTBOX,'value',1);
    end

    function cov_callback(src,~)
        names = get(src,'string');
        selectedDatasetIndex = get(src,'value');
        dsName = names(selectedDatasetIndex(1));
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
        update_ds_text;
    end

    function display_results_callback(src,~)
        displayResults = get(src,'Value');
    end

    function clear_imagesets_callback(~,~)
        if isempty(study.imagesets)
            return;
        end  

        response = questdlg('Clear list of imagesets for this study?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
       
        study.imagesets = [];
        changes_saved = false; 
        updateImageListMenu;
    end

    function plot_imagesets_callback(src,~)
        imagesetName = get(src,'label');
        % fix in 4.2 added subfolder
        imagesetName = strcat('GROUP_ANALYSIS',filesep,imagesetName);
        bw_mip_plot_4D(imagesetName);      
    end

    function updateImageListMenu
            
        if exist('IMAGESETS_MENU','var')
            delete(IMAGESETS_MENU);
            clear IMAGESETS_MENU;
        end
        IMAGESETS_MENU = uimenu('Label','ImageSets');


        if ~isempty(study.imagesets)     
            for k=1:size(study.imagesets,2)
                s = sprintf('%s',char(study.imagesets{k}) ); 
                uimenu(IMAGESETS_MENU,'Label',s,'Callback',@plot_imagesets_callback);              
            end
        end

        % append clear list menu item..
        uimenu(IMAGESETS_MENU,'Label','Clear List','separator','on','Callback',@clear_imagesets_callback); 
        
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % beamformer params controls...
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    function PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyStart=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyEnd=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.step=str2double(get(src,'String'));
    end

    function mean_check_callback(src,~)
       params.beamformer_parameters.mean=get(src,'Value');
    end


    function BASELINE_START_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.baselineStart=str2double(get(src,'String'));
    end
    
    function BASELINE_END_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.baselineEnd=str2double(get(src,'String'));
    end

    function ACTIVE_START_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.activeStart=str2double(get(src,'String'));
    end
    
    function ACTIVE_END_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.activeEnd=str2double(get(src,'String'));
    end

    function ACTIVE_STEP_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.active_step=str2double(get(src,'string'));
    end

    function ACTIVE_NO_STEP_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.no_step=str2double(get(src,'string'));
    end

    function RADIO_ERB_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='ERB';
        updateRadios;
        update_fields;
    end

    function RADIO_Z_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='Z';
        updateRadios;
        update_fields;

    end

    function RADIO_T_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='T';
        updateRadios;
        update_fields;
    end

    function RADIO_F_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='F';
        updateRadios;
        update_fields;
    end

    function set_image_params_callback(~,~)
        
        % open using selected - e.g., to import mesh etc...
        if isempty(study)
            return;
        end
        
        if isempty(selectedDataset)
            errordlg('No dataset selected');
            return;
        end
        
        params = bw_set_image_options(char(selectedDataset), params);
    end


    function plot_images_callback(~,~)
        if isempty(study)
            return;
        end
        
        if study.no_conditions == 0
            return;
        end
        
        if batchJobs.enabled
            response = questdlg('Add to batch?','BrainWave','Yes','Cancel','Cancel');
            if strcmp(response,'Cancel')
                return;
            end  
        end
       
        % get datasets for single condition image, or contrast 
                   
        if conditionType == 1 
            list1 =  study.conditions{condition1};    
            cond1Label =  study.conditionNames{condition1};                           
            list2 = [];
            cond2Label =  '';
            params.beamformer_parameters.contrastImage = 0;
        elseif conditionType == 3
            if condition1 == condition2
                errordlg('Cannot create this contrast: Condition 1 and Condition 2 are the same!');
                return;
            end         
            list1 =  study.conditions{condition1};    
            cond1Label =  study.conditionNames{condition1};
            list2 =  study.conditions{condition2};                
            cond2Label =  study.conditionNames{condition2};
            params.beamformer_parameters.contrastImage = 1;
        end
        
        % change vers4 - need to have a valid covList, but for SAM this is
        % always the condition dataset 
        % i.e., multiDsSAM not available for group analysis (not clear how to make contrasts).
              
        covList = study.conditions{covCondition};
                         
        % check that conditions are compatible. 
        subjectNum = numel(list1);
        if subjectNum ~= numel(covList)
            errordlg('Number of subjects in covariance condition does not match');
            return;
        end
        if conditionType == 3
            if subjectNum ~= numel(list2)
                errordlg('Number of subjects in contrast condition does not match');
                return;
            end
        end
        
        
        for k=1:numel(list1)
            [~, ~, subj_ID, ~, ~] = bw_parse_ds_filename(char(list1(k)) );
            [~, ~, cov_ID, ~, ~] = bw_parse_ds_filename(char(covList(k)) );
            if ~strcmp(subj_ID,cov_ID)
                s = sprintf('Subject dataset ID and Covariance subject ID do not match (line %d)', k);
                errordlg(s);
                return;
            end
            
            if conditionType == 3
                [~, ~, contrast_ID, ~, ~] = bw_parse_ds_filename(char(list2(k)) );
                if ~strcmp(subj_ID,contrast_ID)
                    s = sprintf('Subject dataset ID and Contrast subject ID do not match (line %d)', k);
                    errordlg(s);
                    return;
                end
            end 
        end
        
        % get name for this imageset...
        defName = 'test';
        [fname,pathname,~]=uiputfile('*','Enter name for group images:',defName);   
        if isequal(fname,0)
            return;
        end   
        groupPreFix = fullfile(pathname,fname);        
        
        if batchJobs.enabled
            fprintf('adding group image job %s to batch process...\n', groupPreFix);                
            % make sure each job has unique name 
            if  batchJobs.numJobs > 0
                for i=1:batchJobs.numJobs
                    if strcmp( batchJobs.processes{i}.groupPreFix, groupPreFix)
                        errordlg('Error: Duplicate group image name. Please choose another', 'Batch Processing');
                        return;
                    end
                end
            end
        end        
        
        if batchJobs.enabled
            batchJobs.numJobs = batchJobs.numJobs + 1;
            batchJobs.processes{batchJobs.numJobs}.groupPreFix = groupPreFix;
            batchJobs.processes{batchJobs.numJobs}.list1 = list1;             
            batchJobs.processes{batchJobs.numJobs}.list2 = list2;             
            batchJobs.processes{batchJobs.numJobs}.covList = covList;             
            batchJobs.processes{batchJobs.numJobs}.params = params;

            s = sprintf('Close Batch (%d jobs)', batchJobs.numJobs);
            set(STOP_BATCH,'label',s);                 
        else
            % create images now ...
            
            imagesetName = bw_generate_group_images(groupPreFix, list1, list2, covList, params, cond1Label, cond2Label);
            
            if isempty(imagesetName)
                return;
            end
            % need to save local path name to find mat file
            idx = findstr(filesep,imagesetName);
            fname = imagesetName(idx(end-1)+1:end);
            study.imagesets = [study.imagesets {fname}];
            
            save_changes;
            updateImageListMenu;
            
            % plot results
            if displayResults 
                bw_mip_plot_4D(imagesetName);        
            end

        end
    end

    % batch setup
    function START_BATCH_CALLBACK(~,~)
        batchJobs.enabled = true;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
       
        set(START_BATCH,'enable','off')            
        set(STOP_BATCH,'enable','on')                
        set(STOP_BATCH,'label','Close Batch');               
    end

    function STOP_BATCH_CALLBACK(~,~)
        batchJobs.enabled = false;
        if batchJobs.numJobs > 0
            set(RUN_BATCH,'enable','on')        
            set(STOP_BATCH,'enable','off')            
            set(START_BATCH,'enable','off')            
        else
            set(START_BATCH,'enable','on')        
            set(STOP_BATCH,'enable','off')            
            set(RUN_BATCH,'enable','off')            
        end            
    end

    function RUN_BATCH_CALLBACK(~,~)
        if isempty(batchJobs)
            return;
        end
        numJobs = batchJobs.numJobs;
        s = sprintf('%d group images will be generated.  Do you want to run these now?', numJobs);
        response = questdlg(s,'BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
                 
        for i=1:numJobs
            fprintf('\n\n*********** Running job %d ***********\n\n', i);
            groupPreFix = batchJobs.processes{i}.groupPreFix;
            list1 = batchJobs.processes{i}.list1;
            list2 = batchJobs.processes{i}.list2;
            covList = batchJobs.processes{i}.covList;
            params = batchJobs.processes{i}.params;
            imagesetName = bw_generate_group_images(groupPreFix, list1, list2, covList, params);                           
            if isempty(imagesetName)
                continue;
            end

            % need to save the _IMAGES.mat file with its local path for
            % this group image directory
          
            idx = findstr(filesep,imagesetName);
            fname = imagesetName(idx(end-1)+1:end);
            study.imagesets = [study.imagesets {fname}];          
            save_changes;

            if displayResults      
                bw_mip_plot_4D(imagesetName);
            end
        end
          

        fprintf('\n\n*********** finished batch jobs ***********\n\n');

        batchJobs.enabled = false;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};

        % reset focus to main window before updating menu
        figure(f);
        updateImageListMenu;

        set(START_BATCH,'enable','on')            
        set(RUN_BATCH,'enable','off')        
        set(STOP_BATCH,'enable','off')   
        set(STOP_BATCH,'label','Close Batch');              

        
    end

    function updateRadios

        if strcmp(params.beamformer_parameters.beam.use,'ERB')
            set(RADIO_ERB,'value',1)
            set(RADIO_Z,'value',0)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)

            set_ERB_fields('on');
            set_SAM_fields('off','off');
            set(useSAMBaselineCheck,'enable','off');
            
        else
            set_ERB_fields('off');

            if strcmp(params.beamformer_parameters.beam.use,'Z')
                set(RADIO_Z,'value',1)
                set(RADIO_T,'value',0)
                set(RADIO_F,'value',0)              
                set_SAM_fields('on','off');
                set(useSAMBaselineCheck,'enable','off');
            elseif strcmp(params.beamformer_parameters.beam.use,'T')
                set(RADIO_Z,'value',0)
                set(RADIO_T,'value',1)
                set(RADIO_F,'value',0)
                set_SAM_fields('on','on');
                if conditionType == 3 
                    set(useSAMBaselineCheck,'enable','on');
                else 
                    set(useSAMBaselineCheck,'enable','off');
                end
           elseif strcmp(params.beamformer_parameters.beam.use,'F')
                set(RADIO_Z,'value',0)
                set(RADIO_T,'value',0)
                set(RADIO_F,'value',1)
                set_SAM_fields('on','on');
                if conditionType == 3 
                    set(useSAMBaselineCheck,'enable','on');
                else 
                    set(useSAMBaselineCheck,'enable','off');
                end
            end
            set(RADIO_ERB,'value',0)

        end   
        
    end

    function set_SAM_fields(instr, instr2)
        set(ACTIVE_WINDOW_LABEL,'enable',instr)
        set(ACTIVE_START_EDIT,'enable',instr)
        set(ACTIVE_START_LABEL,'enable',instr)
        set(ACTIVE_END_EDIT,'enable',instr)
        set(ACTIVE_END_LABEL,'enable',instr)
        set(ACTIVE_STEP_LAT_EDIT,'enable',instr)
        set(ACTIVE_STEPSIZE_LABEL,'enable',instr)
        set(ACTIVE_NO_STEP_LABEL,'enable',instr)
        set(ACTIVE_NO_STEP_EDIT,'enable',instr)
        set(BASELINE_WINDOW_LABEL,'enable',instr2)
        set(BASELINE_START_EDIT,'enable',instr2)
        set(BASELINE_START_LABEL,'enable',instr2)
        set(BASELINE_END_EDIT,'enable',instr2)
        set(BASELINE_END_LABEL,'enable',instr2)   

    end

    function set_ERB_fields(instr)
        set(LATENCY_LABEL,'enable',instr)
        set(LAT_START_LABEL,'enable',instr)
        set(LAT_END_LABEL,'enable',instr)
        set(START_LAT_EDIT,'enable',instr)
        set(END_LAT_EDIT,'enable',instr)
        set(LAT_STEPSIZE_LABEL,'enable',instr)
        set(STEPSIZE_EDIT,'enable',instr)
    end

    function QUIT_MENU_CALLBACK(~,~)       
 
        if changes_saved == 0 
            response = questdlg('Save current settings?','BrainWave','Yes','No','Cancel');
            if strcmp(response,'Cancel')
                return;
            end                   
             if strcmp(response,'Yes')
                save_changes;
             end         
        end
                
        delete(f);
    end
end

% helper functions


function filename = removeFilePath(str)
    [~,n,e] = fileparts(str);
    filename = [n e];       
end
    
function  conditionName = getConditionName

    conditionName = [];
    
    fg=figure('color','white','name','New Study','numbertitle','off','menubar','none','position',[100,900, 400 150]);
    if ispc
        movegui(fg,'center')
    end
    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
         'position',[0.05 0.7 0.6 0.2],'String','Enter Name for this condition:','Backgroundcolor','white','fontsize',13);

    COND_NAME = uicontrol('style','edit','units','normalized','HorizontalAlignment','Left',...
         'position',[0.05 0.25 0.6 0.3],'String','','Backgroundcolor','white','fontsize',13);
    
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.25 0.2 0.3],'string','OK','backgroundcolor','white','callback',@ok_callback);
    
    function ok_callback(~,~)    
        conditionName = get(COND_NAME,'string');
        uiresume(gcf);
    end
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);     
    
end



