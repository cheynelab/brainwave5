function bw_plot_dialog( VS_DATA1, params)
%
% old syntax.
% function bw_plot_dialog( VS_DATA1.dsList, VS_DATA1.voxelList, VS_DATA1.orientationList, params, vs_params, tfr_params)
%
%   DESCRIPTION: Creates a GUI that allow users to set some options for
%   virtual sensor calculations
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
% Feb 2022 - rewrite for version 4.0  - removed conditions. Reformated
% layout - can pass additional peaks directly to open dialog
% 
% Aug 2014 - pass VS coordinates so they can be manipulated / edited here...

    global g_peak
    global addPeakFunction
    global PLOT_WINDOW_OPEN

    scrnsizes=get(0,'MonitorPosition');
    button_orange = [0.8,0.4,0.1];
        
    % initial settings    
    if ~exist('VS_DATA1','var')
        VS_DATA1.dsList{1} = 'not_selected';
        VS_DATA1.covDsList{1} = 'not_selected';
        VS_DATA1.voxelList(1,1:3) = [0 0 10];
        VS_DATA1.orientationList(1,1:3) = [1 0 0]; 
        VS_DATA1.labelList{1} = 'not_selected';
        params = bw_setDefaultParameters;
    end
    
    if isempty(params)       
        % if passing data with no params struct 
        % ensure that covWindow is not set to [0 0] 
        if ~isempty(VS_DATA1)
            dsName = char(VS_DATA1.dsList{1});
            params = bw_setDefaultParameters(dsName);
        else
            params = bw_setDefaultParameters();     
        end
        VS_DATA1.labelList{1} = 'none';
    end
   
    % override some defaults

    params.vs_parameters.subtractAverage = 0;
    params.vs_parameters.saveSingleTrials = 0;
    params.tfr_parameters.method = 0;

    useNormal = 0;
    selectedRows = 1;
    
    PLOT_WINDOW_OPEN = 1;

    % use beamformer type passed in beamformer_parameter
    useNormal = 0;
     
    titleStr = sprintf('Virtual Sensor Analysis');
    
    fg=figure('color','white','name',titleStr,'numbertitle','off',...
        'menubar','none','position',[scrnsizes(1,3)/3 scrnsizes(1,4)/2 1200 480],'CloseRequestFcn', @close_callback);
    if ispc
        movegui(fg,'center');
    end
    FILE_MENU = uimenu('label','File');
    
    uimenu(FILE_MENU,'label','Load Voxel List (*.vs) ...','Callback',@open_vlist_callback);
    uimenu(FILE_MENU,'label','Save Voxel List (*.vs)...','Callback',@save_vlist_callback);
    uimenu(FILE_MENU,'label','Save VS Data (*.mat)...','separator','on','Callback',@save_raw_callback);
    uimenu(FILE_MENU,'label','Close','separator','on','accelerator','W','Callback',@close_callback);
    

    %%%%%%%%%%%%
    % VS parameters and data   
    
    annotation('rectangle',[0.02 0.45 0.59 0.5],'EdgeColor','blue');
    uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.03 0.935 0.2 0.03],'string','Virtual Sensor Parameters','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    uicontrol('Style','Text','FontSize',11,'Units','Normalized','fontsize',11,'Position',...
        [0.03 0.86 0.11 0.06],'String','VS Coordinates:','BackgroundColor','White','HorizontalAlignment','Left');   

    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.03 0.82 0.5 0.06],...
        'String','Position (cm)            Orientation           Dataset            (Covariance Dataset )       Label',...
        'BackgroundColor','White');  

    vsListBox=uicontrol('style','listbox','units','normalized','position',...
        [0.03 0.52 0.55 0.31],'fontsize',10,'max',10000,'background','white','callback', @listBoxCallback);    

     uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.03 0.46 0.08 0.05],'string','Edit','callback',@listEditCallback);
    
    uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.13 0.46 0.08 0.05],'string','Delete','callback',@listDeleteCallback); 

    uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.25 0.46 0.08 0.05],'string','Copy','callback',@listCopyCallback); 


    function listCopyCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        if size(selectedRows,2) > 1
            errordlg('Select single VS to copy')
            return;
        end      
        VS_DATA1.voxelList(end+1,:) = VS_DATA1.voxelList(selectedRows,:);
        VS_DATA1.orientationList(end+1,:) = VS_DATA1.orientationList(selectedRows,:);
        VS_DATA1.dsList(end+1) = VS_DATA1.dsList(selectedRows);
        VS_DATA1.covDsList(end+1) = VS_DATA1.covDsList(selectedRows);    
        VS_DATA1.labelList{end+1} =  VS_DATA1.labelList{selectedRows};
        updateDataWindow;   
    end

    function listEditCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        if size(selectedRows,2) > 1
            errordlg('Select single VS to edit')
            return;
        end      
        edit_selected_VS(selectedRows);     
    end

    function listDeleteCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        numToDelete = size(selectedRows,2);

        s = sprintf('Delete %d virtual sensors', numToDelete);
        response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
        if strcmp(response,'Cancel')
            return;     
        end        
        VS_DATA1.voxelList(selectedRows,:) = [];
        VS_DATA1.orientationList(selectedRows,:) = [];
        VS_DATA1.dsList(selectedRows) = [];
        VS_DATA1.covDsList(selectedRows) = [];
        VS_DATA1.labelList(selectedRows)= [];
        set(vsListBox,'value',1);
        updateDataWindow;   
    end

    function listBoxCallback(src, ~)        
       if strcmp( get(gcf,'selectiontype'), 'open')     % look for double click only           
           selectedRows = get(src,'value');             
           edit_selected_VS(selectedRows);          
       else
           selectedRows = get(src,'value');
       end       
    end       

    function edit_selected_VS(selection)
       if isempty(VS_DATA1.voxelList)
           return;
       end
       pos = VS_DATA1.voxelList(selection,1:3);
       ori = VS_DATA1.orientationList(selection,1:3);
       dsName = VS_DATA1.dsList{selection};
       covDsName = VS_DATA1.covDsList{selection};  
       label =  VS_DATA1.labelList{selection};
       
       [pos, ori, dsName, covDsName, label] = bw_vs_params_dialog(pos, ori, dsName, covDsName, label);  % edit CTF coords only

       if ~isempty(pos)
            VS_DATA1.voxelList(selection,1:3) = pos;
            VS_DATA1.orientationList(selection,1:3) = ori;
            VS_DATA1.dsList{selection} = dsName;
            VS_DATA1.covDsList{selection} = covDsName;
            VS_DATA1.labelList{selection} = label;
            updateDataWindow;
       end       
    end

    function updateDataWindow
        tlist = {};
     
        for k=1:size(VS_DATA1.voxelList,1)
            dsName = char(VS_DATA1.dsList{k});
            covDsName = char(VS_DATA1.covDsList{k});     
            voxel = VS_DATA1.voxelList(k,1:3);
            orientation = VS_DATA1.orientationList(k,1:3);         
            label = char(VS_DATA1.labelList{k});
            
            s = sprintf('%6.2f %6.2f %6.2f    %6.2f %6.2f %6.2f     %s         (%s)       %s',...
                voxel, orientation, dsName, covDsName, label );                  
            tlist(k,:) = cellstr(s);
        end
        set(vsListBox,'string',tlist);

    end

    % beamformer params

    annotation('rectangle',[0.63 0.05 0.34 0.9],'EdgeColor','blue');
    uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.65 0.935 0.2 0.03],'string','Beamformer Parameters','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');
   
    uicontrol('Style','Text','FontSize',11,'Units','Normalized','fontsize',11,'fontweight','bold','Position',...
        [0.65 0.835 0.1 0.06],'String','Source Units:','BackgroundColor','White','HorizontalAlignment','Left');    
    MOMENT_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',11,'position',...
        [0.75 0.85 0.1 0.06],'string','Moment','backgroundcolor','white','value',~params.vs_parameters.pseudoZ,'callback',@MOMENT_RADIO_CALLBACK);
    PSEUDOZ_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',11,'position',...
        [0.83 0.85 0.1 0.06],'string','Pseudo-Z','backgroundcolor','white','value',params.vs_parameters.pseudoZ,'callback',@PSEUDOZ_RADIO_CALLBACK);    
            
    function MOMENT_RADIO_CALLBACK(~,~)
        params.vs_parameters.pseudoZ=0;
        set(PSEUDOZ_RADIO,'value',0)
        set(MOMENT_RADIO,'value',1)
    end

    function PSEUDOZ_RADIO_CALLBACK(~,~)
        params.vs_parameters.pseudoZ=1;
        set(PSEUDOZ_RADIO,'value',1)
        set(MOMENT_RADIO,'value',0)
    end


    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.79 0.2 0.05],'String','Source Orientation:','FontSize',11,'Fontweight','bold','BackGroundColor','white');
   
    ORIENTATION_POPUP_MENU = uicontrol('style','popup','units','normalized','position', [0.65 0.75 0.27 0.04],...
        'string',{'Optimized (maximum power)';'Constrained (use orientation vector)';'RMS (vector beamformer)'},'FontSize', 11,'callback',@orientation_menu_callback);
   
        function orientation_menu_callback(src,~)
            val = get(src,'value');
            if val == 1
                useNormal = 0;
                params.vs_parameters.rms = 0;
            elseif val == 2
                useNormal = 1;                
                params.vs_parameters.rms = 0;
            elseif val == 3
                params.vs_parameters.rms = 1;
            end
            updateRMSControls;               
        end


    params.vs_parameters.rms = params.beamformer_parameters.rms;
    if params.vs_parameters.rms
        set(ORIENTATION_POPUP_MENU,'value',3);
    else
        set(ORIENTATION_POPUP_MENU,'value',1);
    end    
    

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.67 0.2 0.05],'String','Filter Data:','FontSize',11,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.65 0.615 0.1 0.05],'String','Highpass (Hz):','FontSize',11,'BackGroundColor','white');

    FILTER_EDIT_MIN=uicontrol('style','edit','units','normalized','position',...
        [0.74 0.62 0.05 0.05],'String', params.beamformer_parameters.filter(1),...
        'FontSize', 11, 'BackGroundColor','white','callback',@filter_edit_min_callback);
        function filter_edit_min_callback(src,~)
            string_value=get(src,'String');
            if isempty(string_value)
                params.beamformer_parameters.filter(1) = 1;
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
                params.beamformer_parameters.filter(2) = 50;
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
                clear dsParams;
            else
                dsName = char(VS_DATA1.dsList{selectedRows(1)});
                dsParams = bw_CTFGetHeader(dsName);
                params.beamformer_parameters.filter(1)=str2double(string_value);
                if params.beamformer_parameters.filter(1) < 0
                    params.beamformer_parameters.filter(1) = 0;
                end
                if params.beamformer_parameters.filter(1) > dsParams.sampleRate / 2.0
                    params.beamformer_parameters.filter(1) = dsParams.sampleRate / 2.0;
                end
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
            end
        end

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.8 0.615 0.1 0.05],'String','Lowpass (Hz):','FontSize',11,'BackGroundColor','white');

    FILTER_EDIT_MAX=uicontrol('style','edit','units','normalized','position',...
        [0.89 0.62 0.05 0.05],'String',params.beamformer_parameters.filter(2),...
        'FontSize', 11, 'BackGroundColor','white','callback',@filter_edit_max_callback);
        function filter_edit_max_callback(src,~)
            string_value=get(src,'String');
            if isempty(string_value)
                params.beamformer_parameters.filter(2)=50;
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
                params.filter(1)=1;
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
            else
                dsName = char(VS_DATA1.dsList{selectedRows(1)});
                dsParams = bw_CTFGetHeader(dsName);
                params.beamformer_parameters.filter(2)=str2double(string_value);
                if params.beamformer_parameters.filter(2) > dsParams.sampleRate
                    params.beamformer_parameters.filter(2) = dsParams.sampleRate;
                end
                if params.beamformer_parameters.filter(2) < 0
                    params.beamformer_parameters.filter(2)=0;
                end
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
                clear dsParams;
            end
        end
    


    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.55 0.2 0.05],'String','Baseline Correction:','FontSize',11,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.495 0.1 0.05],...
            'String','Start (s):','FontSize',11,'BackGroundColor','white');
    
    BASELINE_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.7 0.5 0.05 0.05],...
            'String', params.beamformer_parameters.baseline(1), 'FontSize', 11, 'BackGroundColor','white','callback',@baseline_edit_min_callback);
        
        function baseline_edit_min_callback(src,~)
            string_value=get(src,'String');          
            params.beamformer_parameters.baseline(1)=str2double(string_value);
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            if params.beamformer_parameters.baseline(1) < dsParams.epochMinTime || params.beamformer_parameters.baseline(1) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(1)= dsParams.epochMinTime;
                set(BASELINE_EDIT_MIN,'string',params.baseline(1))
            end   
        end
    
    
    uicontrol('style','text','units','normalized','position',[0.76 0.495 0.05 0.05],...
            'String','End (s):','FontSize',11,'BackGroundColor','white');
    BASELINE_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.81 0.5 0.05 0.05],...
            'String', params.beamformer_parameters.baseline(2), 'FontSize', 11, 'BackGroundColor','white','callback',@baseline_edit_max_callback);
        function baseline_edit_max_callback(src,~)
            string_value=get(src,'String');          
            params.beamformer_parameters.baseline(2)=str2double(string_value);
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            if params.beamformer_parameters.baseline(2) < dsParams.epochMinTime || params.beamformer_parameters.baseline(2) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(2) = dsParams.epochMaxTime;
                set(BASELINE_EDIT_MAX,'string',params.baseline(2))
            end   
        end
       
    uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','left','position', [0.87 0.5 0.07 0.05],...
            'string', 'full range', 'FontSize', 11, ...
            'ForeGroundColor','blue','callback',@baseline_set_full_callback);
    
         function baseline_set_full_callback(~,~)              
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
            params.beamformer_parameters.baseline(2) = dsParams.epochMaxTime;
            set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
            set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))    
         end        
        
    
    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.42 0.2 0.05],'String','Covariance Window:','FontSize',11,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.365 0.1 0.05],...
            'String','Start (s):','FontSize',11,'BackGroundColor','white');

    COV_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.7 0.37 0.05 0.05],...
            'String', params.beamformer_parameters.covWindow(1), 'FontSize', 11, 'BackGroundColor','white','callback',@cov_edit_min_callback);

    function cov_edit_min_callback(src,~)
            string_value=get(src,'String');          
            params.beamformer_parameters.covWindow(1)=str2double(string_value);
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            if params.beamformer_parameters.covWindow(1) < dsParams.epochMinTime || params.beamformer_parameters.covWindow(1) > dsParams.epochMaxTime
                params.beamformer_parameters.covWindow(1) = params.beamformer_parameters.covWindow(1);
                set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
            end   
        end


    uicontrol('style','text','units','normalized','position',[0.76 0.365 0.05 0.05],...
            'String','End (s):','FontSize',11,'BackGroundColor','white');
    COV_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.81 0.37 0.05 0.05],...
            'String', params.beamformer_parameters.covWindow(2), 'FontSize', 11, 'BackGroundColor','white','callback',@cov_edit_max_callback);
    function cov_edit_max_callback(src,~)
            string_value=get(src,'String');          
            params.beamformer_parameters.covWindow(2)=str2double(string_value);
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            if params.beamformer_parameters.covWindow(2) < dsParams.epochMinTime || params.beamformer_parameters.covWindow(2) > dsParams.epochMaxTime
                params.beamformer_parameters.covWindow(2) = params.beamformer_parameters.covWindow(2);
                set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))
            end   
        end

    uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','left','position', [0.87 0.37 0.07 0.05],...
            'string', 'full range', 'FontSize', 11, ...
            'ForeGroundColor','blue','callback',@cov_set_full_callback);

    function cov_set_full_callback(~,~)              
            dsName = char(VS_DATA1.dsList{selectedRows(1)});
            dsParams = bw_CTFGetHeader(dsName);
            params.beamformer_parameters.covWindow(1) = dsParams.epochMinTime;
            params.beamformer_parameters.covWindow(2) = dsParams.epochMaxTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))       
    end           


     % note params.regulalarization holds the power (in Telsa squared) to add to diagonal    
     reg_fT = sqrt(params.beamformer_parameters.regularization) * 1e15;  %% convert to fT  RMS for edit box

     reg_check = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.67 0.3 0.2 0.05],'val',params.beamformer_parameters.useRegularization,'String','Diagonal regularization', ...
        'BackgroundColor','White', 'Callback',@reg_check_callback);
        function reg_check_callback(src,~)
            val=get(src,'Value');
            if (val)
                params.beamformer_parameters.useRegularization = 1;
                set(REG_EDIT,'enable','on')
            else
                params.beamformer_parameters.useRegularization = 0;
                set(REG_EDIT,'enable','off')
            end
        end     

     REG_EDIT=uicontrol('style','edit','units','normalized','position', [0.83 0.295 0.04 0.05],...
        'String', reg_fT, 'FontSize', 11, 'BackGroundColor','white','callback',@reg_edit_callback);
     function reg_edit_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.regularization = 0;
            set(REG_EDIT,'string',params.beamformer_parameters.regularization);
        else
            reg_fT = str2double(string_value);            
            params.beamformer_parameters.regularization = (reg_fT * 1e-15)^2; % convert from fT squared to Tesla squared 
        end
     end
     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.88 0.295 0.08 0.04],...
        'String','fT / sqrt(Hz)','FontSize',11,'BackGroundColor','white');


    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.22 0.2 0.05],'String','Head Model:','FontSize',11,'Fontweight','bold','BackGroundColor','white');
    
    HDM_RADIO=uicontrol('style','radio','units','normalized','position',[0.65 0.18 0.14 0.05],...
    'string','HDM File:','Fontsize',11,'Backgroundcolor','white','value',params.beamformer_parameters.useHdmFile,'callback',@hdm_radio_callback);
    function hdm_radio_callback (~,~)
        params.beamformer_parameters.useHdmFile = 1;
        set(SPHERE_RADIO,'value',0);
        set(HDM_RADIO,'value',1);
        set(HDM_EDIT,'enable','on');
        set(HDM_SELECT,'enable','on');
        set(SPHERE_EDIT,'enable','off');
        set(SPHERE_TXT,'enable','off')
    end
    HDM_EDIT = uicontrol('style','edit','units','normalized','position', [0.74 0.18 0.14 0.05],...
        'String', params.beamformer_parameters.hdmFile, 'FontSize', 11, 'BackGroundColor','white','callback',@hdm_edit_callback);
    function hdm_edit_callback(src,~)
        params.beamformer_parameters.hdmFile=get(src,'String');
        if isempty(params.beamformer_parameters.hdmFile)
             params.beamformer_parameters.hdmFile = '';
        end
    end

    HDM_SELECT = uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','left','position', [0.91 0.18 0.05 0.05],...
            'string', 'Select', 'FontSize', 11, ...
            'ForeGroundColor','blue','callback',@HDM_PUSH_CALLBACK);
    function HDM_PUSH_CALLBACK(~,~)
        
        s = fullfile(char(dsName),'*.hdm');
        [hdmfilename , hdmpathname,~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if isequal(hdmfilename,0) || isequal(hdmpathname,0)
          return;
        end
                    
        dsName = char(VS_DATA1.dsList{selectedRows(1)});
        
        hdmPath = hdmpathname(1:end-1);
        [~,hdmDs,~,~,~] = bw_parse_ds_filename(dsName);
        hdmFile = fullfile(hdmpathname,hdmfilename);
        if ~strcmp(dsName,hdmDs)
            s = sprintf('Copying headmodel file %s to the current dataset?', dsName);
            warndlg(s);
            s = sprintf('cp %s %s', hdmFile, dsName);
            system(s);            
        end
        params.beamformer_parameters.hdmFile = hdmfilename;

        set(HDM_EDIT,'string',hdmfilename)
        if isempty(params.beamformer_parameters.hdmFile)
            params.beamformer_parameters.hdmFile = '';
        end
    end


    SPHERE_RADIO=uicontrol('style','radio','units','normalized','position',[0.65 0.10 0.14 0.05],...
    'string','Single Sphere:','Fontsize',11,'Backgroundcolor','white','value',params.beamformer_parameters.useHdmFile,'callback',@sphere_radio_callback);
    function sphere_radio_callback (~,~)
        params.beamformer_parameters.useHdmFile = 0;
        set(SPHERE_RADIO,'value',1);
        set(HDM_RADIO,'value',0);
        set(HDM_EDIT,'enable','off');
        set(HDM_SELECT,'enable','off');
        set(SPHERE_EDIT,'enable','on');
        set(SPHERE_TXT,'enable','on');
    end

    s = sprintf('X=%.2f  Y=%.2f  Z=%.2f  cm', params.beamformer_parameters.sphere);
    SPHERE_TXT = uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.745 0.085 0.2 0.05],'String',s,'FontSize',10,'Fontweight','normal','BackGroundColor','white');
        params.sphere(1)=0;
    SPHERE_EDIT = uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','left','position', [0.91 0.10 0.05 0.05],...
            'string', 'Edit', 'FontSize', 11, ...
            'ForeGroundColor','blue','callback',@SPHERE_EDIT_CALLBACK);
    function SPHERE_EDIT_CALLBACK(~,~)      
        newSphere = params.beamformer_parameters.sphere;
        s1 = sprintf('%.2f', newSphere(1));
        s2 = sprintf('%.2f', newSphere(2));
        s3 = sprintf('%.2f', newSphere(3));
        input = inputdlg({'X (cm)'; 'Y (cm)'; 'Z (cm)'},'Enter Sphere Origin ',[1 50; 1 50; 1 50], {s1; s2; s3} );         
        if isempty(input)
            return;
        end
        
        params.beamformer_parameters.sphere =[ str2double(input{1}) str2double(input{2}) str2double(input{3}) ];
        s = sprintf('X = %.2f  Y = %.2f  Z = %.2f  cm', params.beamformer_parameters.sphere);
        set(SPHERE_TXT,'String',s);

    end
    %%%%%%%


    %%%%%%%
    if isempty(VS_DATA1)
        % need to set some valid params.
        params = bw_setDefaultParameters; 
    else
        if isempty(VS_DATA1.orientationList)
            for k=1:size(VS_DATA1.voxelList,1)        
                VS_DATA1.orientationList(k,1:3) = [1 0 0];
            end       
        end        
        updateDataWindow;
    end
    

    function updateRMSControls
        if params.vs_parameters.rms        
            set(AUTOFLIP_CHECK,'enable','off');
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
            set(AUTOFLIP_POS_RADIO,'enable','off');
            set(AUTOFLIP_NEG_RADIO,'enable','off');    
        else
            set(AUTOFLIP_CHECK,'enable','on');
            if params.vs_parameters.autoFlipLatency
                set(AUTOFLIP_EDIT,'enable','on');
                set(AUTOFLIP_TEXT1,'enable','on');
                set(AUTOFLIP_POS_RADIO,'enable','on');
                set(AUTOFLIP_NEG_RADIO,'enable','on'); 
            end
        end  
    end

    function addGlobalPeak
        VS_DATA1.dsList{end+1} = g_peak.dsName;
        VS_DATA1.covDsList{end+1} = g_peak.covDsName;
        VS_DATA1.voxelList(end+1,1:3) = g_peak.voxel;
        VS_DATA1.orientationList(end+1,1:3) =  g_peak.normal;
        VS_DATA1.labelList{end+1} = g_peak.label;
                 
        updateDataWindow;

        figure(fg);     % bring window to front.
    end

    addPeakFunction = @addGlobalPeak;

    %%%%%%%%%%%%
    % VS plot
    
    annotation('rectangle',[0.29 0.05 0.32 0.36],'EdgeColor','blue');
    uicontrol('style','text','fontsize',11,'units','normalized','Position',...
    [0.33 0.375 0.18 0.05],'string','Virtual Sensor Plot','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
    AVERAGE_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.32 0.32 0.15 0.05],'val',~params.vs_parameters.saveSingleTrials,'String','Average only','BackgroundColor','White', 'Callback',@AVERAGE_CALLBACK);
    SINGLE_TRIALS_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.42 0.32 0.15 0.05],'val',params.vs_parameters.saveSingleTrials,'String','Average + Single Trials','BackgroundColor','White', 'Callback',@SINGLE_TRIALS_CALLBACK);
    
    AUTOFLIP_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.32 0.25 0.2 0.05],'val',params.vs_parameters.autoFlip,'String','Autoflip polarity','BackgroundColor','White', 'Callback',@AUTOFLIP_CHECK_CALLBACK);
    AUTOFLIP_POS_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.32 0.18 0.14 0.05],'val',params.vs_parameters.autoFlipPolarity,'String','positive at','BackgroundColor','White', 'Callback',@AUTOFLIP_POS_CALLBACK);
    AUTOFLIP_NEG_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.4 0.18 0.14 0.05],'val',~params.vs_parameters.autoFlipPolarity,'String','negative at','BackgroundColor','White', 'Callback',@AUTOFLIP_NEG_CALLBACK);   
    AUTOFLIP_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',11,'Position',...
        [0.5 0.18 0.05 0.05],'String',num2str(params.vs_parameters.autoFlipLatency),'BackgroundColor','White');
    AUTOFLIP_TEXT1 = uicontrol('Style','text','Units','Normalized','fontsize',11,'Position',...
        [0.56 0.17 0.03 0.05],'String','sec','BackgroundColor','White','HorizontalAlignment','Left');
             
    function AUTOFLIP_CHECK_CALLBACK(src,~)
        params.vs_parameters.autoFlip = get(src,'val');
        
        if params.vs_parameters.autoFlip
            set(AUTOFLIP_EDIT,'enable','on');
            set(AUTOFLIP_TEXT1,'enable','on');
            set(AUTOFLIP_POS_RADIO,'enable','on');
            set(AUTOFLIP_NEG_RADIO,'enable','on');
        else
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
            set(AUTOFLIP_POS_RADIO,'enable','off');
            set(AUTOFLIP_NEG_RADIO,'enable','off');
        end
        
    end

    function AUTOFLIP_POS_CALLBACK(src,~)
        params.vs_parameters.autoFlipPolarity = 1;
        set(src,'value',1);        
        set(AUTOFLIP_NEG_RADIO,'value',0);        
    end

    function AUTOFLIP_NEG_CALLBACK(src,~)
        params.vs_parameters.autoFlipPolarity = -1;
        set(src,'value',1);        
        set(AUTOFLIP_POS_RADIO,'value',0);        
    end

    function AVERAGE_CALLBACK(src,~)
        set(src,'value',1);
        params.vs_parameters.saveSingleTrials = 0;
        set(SINGLE_TRIALS_RADIO,'value',0);
    end    

    function SINGLE_TRIALS_CALLBACK(src,~)
        set(src,'value',1);
        params.vs_parameters.saveSingleTrials = 1;
        set(AVERAGE_RADIO,'value',0);
    end

    function plot_VS_callback(~,~)
        
        if isempty(VS_DATA1.dsList)
            return;
        end
        
        if params.vs_parameters.autoFlip
            strval = get(AUTOFLIP_EDIT,'String');
            params.vs_parameters.autoFlipLatency = str2double(strval);
        end
                
        rows = selectedRows;
                
        if useNormal  
            oriList = VS_DATA1.orientationList(rows,1:3);
        else
            oriList = [];
        end
                
        VS_ARRAY1 = bw_create_VS(VS_DATA1.dsList(rows), VS_DATA1.covDsList(rows), VS_DATA1.voxelList(rows,1:3),...
                oriList, VS_DATA1.labelList(rows), params); 
        if isempty(VS_ARRAY1)
            return;
        end
        
        params.vs_parameters.plotLabel = sprintf('Average');
        params.vs_parameters.plotColor = [0 0 1];
        params.vs_parameters.subtractAverage = 0;
        bw_VSplot(VS_ARRAY1, params); 
       
    end

    %%%%%%%%%%%%
    % TFR plot
    
    annotation('rectangle',[0.02 0.05 0.25 0.36],'EdgeColor','blue');
    uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.03 0.375 0.18 0.05],'string','Time-Frequency Plot','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.05 0.29 0.18 0.05],'String','Frequency Step (Hz)','BackgroundColor','White');
    FREQ_BIN_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',11,'Position',...
        [0.18 0.3 0.06 0.05],'String',num2str(params.tfr_parameters.freqStep),'BackgroundColor','White');    
    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',11,'Position',...
        [0.05 0.22 0.2 0.05],'String','Wavelet Width (cycles):','BackgroundColor','White');
    MORLET_CYCLE_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',11,'Position',...
        [0.18 0.23 0.06 0.05],'String',num2str(params.tfr_parameters.fOversigmafRatio),'BackgroundColor','White');    
   
    SAVE_MAG_PHASE_CHECK = uicontrol('style','checkbox','units','normalized','fontsize',11,'position',...
        [0.05 0.16 0.2 0.05],'BackgroundColor','White','string','Save Trial Magnitude/Phase','value',...
        params.tfr_parameters.saveSingleTrials, 'callback',@TFR_SAVE_TRIALS_CALLBACK);  

    function TFR_SAVE_TRIALS_CALLBACK(src,~)
        params.tfr_parameters.saveSingleTrials = get(src,'value');
    end

    
    
    function plot_TFR_callback(~,~)

        if isempty(VS_DATA1.dsList)
            return;
        end
        
        s = get(FREQ_BIN_EDIT,'String');
        params.tfr_parameters.freqStep = str2double(s);
        
        s = get(MORLET_CYCLE_EDIT,'String');
        params.tfr_parameters.fOversigmafRatio = str2double(s);

        rows = selectedRows;
        
        if useNormal  
            oriList = VS_DATA1.orientationList(rows,1:3);
        else
            oriList = [];
        end

        TFR_ARRAY1 = bw_create_TFR(VS_DATA1.dsList(rows),VS_DATA1.covDsList(rows),VS_DATA1.voxelList(rows,1:3),...
            oriList, VS_DATA1.labelList(rows), params); 
       
        if isempty(TFR_ARRAY1)
            return;
        end
        label = sprintf('Average');
        bw_plot_tfr(TFR_ARRAY1, 0, label);        
            
    end  
    
    tfrButton=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',...
        [0.04 0.07 0.13 0.07],'string','Plot TFR','fontweight','bold','foregroundcolor',button_orange,'callback',@plot_TFR_callback);
    
    vsButton=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',...
        [0.32 0.07 0.13 0.07],'string','Plot VS','fontweight','bold','foregroundcolor',button_orange,'callback',@plot_VS_callback);
           
    if ~ismac
        set(tfrButton,'backgroundcolor','white');
        set(vsButton,'backgroundcolor','white');
    end 

    function updateParameterFields

        % VS params

        set(AUTOFLIP_CHECK,'value',params.vs_parameters.autoFlip);
        if params.vs_parameters.autoFlip
            set(AUTOFLIP_EDIT,'enable','on');
            set(AUTOFLIP_TEXT1,'enable','on');
            set(AUTOFLIP_POS_RADIO,'enable','on');
            set(AUTOFLIP_NEG_RADIO,'enable','on');
            set(AUTOFLIP_EDIT,'String',num2str(params.vs_parameters.autoFlipLatency));
        else
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
            set(AUTOFLIP_POS_RADIO,'enable','off');
            set(AUTOFLIP_NEG_RADIO,'enable','off');
            set(AUTOFLIP_EDIT,'String','0.0');
        end
        if params.vs_parameters.autoFlipPolarity == 1
            set(AUTOFLIP_NEG_RADIO, 'value', 0);
            set(AUTOFLIP_POS_RADIO, 'value', 1);
        else
            set(AUTOFLIP_NEG_RADIO, 'value', 1);
            set(AUTOFLIP_POS_RADIO, 'value', 0);
        end
        set(SINGLE_TRIALS_RADIO,'value',params.vs_parameters.saveSingleTrials);
        set(AVERAGE_RADIO,'value',~params.vs_parameters.saveSingleTrials);
        
        % TFR params

        set(SAVE_MAG_PHASE_CHECK,'value',params.tfr_parameters.saveSingleTrials);
        set(FREQ_BIN_EDIT,'string',num2str(params.tfr_parameters.freqStep));
        set(MORLET_CYCLE_EDIT,'string',num2str(params.tfr_parameters.fOversigmafRatio));

        % beamformer params

        set(MOMENT_RADIO,'value',~params.vs_parameters.pseudoZ);
        set(PSEUDOZ_RADIO,'value',params.vs_parameters.pseudoZ);
           
        if params.vs_parameters.rms
            set(ORIENTATION_POPUP_MENU,'value',3);
        else
            set(ORIENTATION_POPUP_MENU,'value',1);
        end  

        updateRMSControls;

        set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
        set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2)); 
        set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1));
        set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2));
        set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
        set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));    
        
        reg_fT = sqrt(params.beamformer_parameters.regularization) * 1e15;  %% convert to fT  RMS for edit box
        set(REG_EDIT,'string',reg_fT);
        set(reg_check,'value',params.beamformer_parameters.useRegularization);
        if (params.beamformer_parameters.useRegularization)
            set(REG_EDIT,'enable','on')
        else
            set(REG_EDIT,'enable','off')
        end

        if params.beamformer_parameters.useHdmFile
            set(HDM_EDIT, 'String', params.beamformer_parameters.hdmFile);
            hdm_radio_callback;
        else
            s = sprintf('X=%.2f  Y=%.2f  Z=%.2f  cm', params.beamformer_parameters.sphere);
            set(SPHERE_TXT,'string',s);
            sphere_radio_callback;
        end

    end
   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % update all fields with current params
    updateParameterFields;


    % ** old format
    function open_vlist_callback(~, ~)
        [filename, pathname, ~]=uigetfile({'*.vs','Virtual Sensor File (*.vs)'},...
            'Select list file containing virtual sensor parameters');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
                
        listFile = fullfile(pathname, filename);
        
        list = bw_read_list_file(listFile);
        start = 0;
        if size(VS_DATA1.dsList,2) > 1
            s = sprintf('Add to current list?');
            response = questdlg('Add to current list or overwrite?','Load List','Overwrite','Add','Overwrite');
            if strcmp(response,'Add')
                start = size(VS_DATA1.dsList,2);
            end
        end

        for k=1:size(list,1)
            idx = start+k;
            str = char(list(k,:));
            a = strread(str,'%s','delimiter',' ');
            VS_DATA1.dsList{idx} = char( a(1) );
             
            VS_DATA1.covDsList{idx} = char( a(2) );
            VS_DATA1.voxelList(idx,1:3) = str2double( a(3:5))';
            VS_DATA1.orientationList(idx,1:3) = str2double( a(6:8))';  
            VS_DATA1.orientationList(idx,1:3) = str2double( a(6:8))';  
            VS_DATA1.labelList{idx} = char( a(9) );
        end

        set(vsListBox,'value',1);
        VS_DATA1.condLabel = filename;

        % new 4.1 - load saved parameters if exist
        params_file = strcat(listFile,'.mat');
        if exist(params_file,'file')
            fprintf('Reading VS parameters from %s\n',params_file);
            params = load(params_file);
            updateParameterFields;
        end
        
        updateDataWindow;
              
        s = sprintf('Virtual Sensor Analysis (%s)',listFile);
        set(fg,'name',s);

        
    end
      
    function save_vlist_callback(~, ~)
 
        if isempty(VS_DATA1)
            return;
        end
        
        [filename, pathname, ~]=uiputfile({'*.vs','Virtual Sensor File (*.vs)'},'Save virtual sensor parameters for Condition 1 as...');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end      
        saveName = fullfile(pathname, filename);
        save_VS_File( VS_DATA1, saveName);

        % new 4.1 - save parameters

        % make sure edit fields are updated
        s = get(FREQ_BIN_EDIT,'String');
        params.tfr_parameters.freqStep = str2double(s);
        
        s = get(MORLET_CYCLE_EDIT,'String');
        params.tfr_parameters.fOversigmafRatio = str2double(s);


        params_file = strcat(saveName,'.mat');
        save(params_file,'-struct','params');

    end

    function save_VS_File(VS_DATA, saveName)
                                  
        fprintf('Saving voxel parameters in file %s\n', saveName);
        fid = fopen(saveName,'w');
                     
        for j=1:size(VS_DATA.voxelList,1)
            dsName = char(VS_DATA.dsList{j});
            covDsName = char(VS_DATA.covDsList{j});
            voxel = VS_DATA.voxelList(j,1:3);
            normal = VS_DATA.orientationList(j,1:3);
            label = char(VS_DATA.labelList{j});
            s = sprintf('%s    %s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f    %s', dsName, covDsName, voxel, normal, label);    
            fprintf(fid,'%s\n', s);           
        end        
        
        fclose(fid);
        s = sprintf('Virtual Sensor Analysis (%s)',saveName);
        set(fg,'name',s);
                
    end

    function save_raw_callback(~,~)

        if isempty(VS_DATA1)
            return;
        end
                       
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)
       
        tic;
                    
        [name,path,idx] = uiputfile({'*.mat','MAT-file (*.mat)';'*','ASCII files (Directory)';},...
                'Select output name virtual sensor data for condition %d ...',char(k));
        if isequal(name,0)
            return;
        end
        path = fullfile(path,name);

        if idx == 1
            saveMatFile = true;
        else
            saveMatFile = false;
            fprintf('Saving virtual sensor raw data to directory %s\n', path); 
            mkdir(path);          
        end

        % assume voxel list sizes are the same for all conditions
        for j=1:size(VS_DATA1.voxelList,1)
            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** cancelled ***\n');
                return;
            end
            waitbar(j/size(VS_DATA1.voxelList,1),wbh,sprintf('generating virtual sensor %d',j));

            % get raw data...
            fprintf('computing single trial data ...\n');

            % override some parameters...
            params.vs_parameters.saveSingleTrials = 1;
            voxel = VS_DATA1.voxelList(j,1:3);
            normal = VS_DATA1.orientationList(j,1:3);
            dsName = char(VS_DATA1.dsList{j});
            covDsName = char(VS_DATA1.covDsList{j});

            [timeVec, vs_data_raw, comnorm] = bw_make_vs(dsName, covDsName, voxel, normal, params);

            [samples, trials] = size(vs_data_raw);

            % store all data in one matfile 
            %
            % format:
            % vsdata.timeVec = 1D array of latencies (nsamples x 1)
            % vsdata.voxels = 2D array of voxel coords (nvoxels x 6)
            % vsdata.trials = 3D array of vs data (nvoxels x ntrials x nsamples)

            if saveMatFile
                vsdata.timeVec = timeVec;
                vox_params = [voxel comnorm'];
                vsdata.voxel(j,1:6) = vox_params;
                vsdata.trial(j,1:trials,1:samples) = single(vs_data_raw');    % save as single precision - reduces file size by 50%       
            else
                outFile = sprintf('%s%s%s_voxel_%4.2f_%4.2f_%4.2f.raw', ...
                    path, filesep, char(dsName), voxel(1), voxel(2), voxel(3));
                fid = fopen(outFile,'w');
                fprintf('Saving single trial data in file %s\n', outFile);
                for i=1:size(vs_data_raw,1)
                    fprintf(fid, '%.4f', timeVec(i));
                    for k=1:size(vs_data_raw,2)
                        fprintf(fid, '\t%8.4f', vs_data_raw(i,k) );
                    end   
                    fprintf(fid,'\n');
                end
                fclose(fid);                 
            end

        end
        delete(wbh);  
        toc

        if saveMatFile
            fprintf('Writing VS data to file %s\n', path);
            save(path,'-struct','vsdata');
        end
        
        
        fprintf('\n...all done\n');
        
    end


    function close_callback(~,~)  
        PLOT_WINDOW_OPEN = 0;
        uiresume(gcf);
        delete(fg);   
    end    

end