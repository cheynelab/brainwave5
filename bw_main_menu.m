    function bw_main_menu
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Brainwave5
%
%   DESCRIPTION: Creates BrainWave main GUI. 
%   (c) D. Cheyne, 2011. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   original version June, 2012, Version 2.0
%   
%   This is now main menu to define globals and launch other modules
%
%   current release, May, 2025, Version 5.0
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    global BW_VERSION;
    global RELEASE_DATE;
    global BW_PATH;
    global HAS_SIGNAL_PROCESSING
    global defaultPrefsFile

    fig_handles = [];

    BW_VERSION = 5.3;
    RELEASE_DATE = 'April 9, 2026';
    
    % check Matlab version
    versionStr = version;
    versionNo = str2double(versionStr(1:3));   
    if versionNo < 9.0
        warndlg('MATLAB Version 9.0 or later recommended');
    end
    
    result = license('test','signal_toolbox');
    if result == 1
        HAS_SIGNAL_PROCESSING = true;
    else
        HAS_SIGNAL_PROCESSING = false;
        fprintf('Signal processing toolbox not found. Some feature may not be available\n');
    end    

    tpath=which('bw_main_menu');

    pathparts = strsplit(tpath,filesep);
    s = pathparts(1:end-1);
    BW_PATH = strjoin(s,filesep);
    BW_PATH = strcat(BW_PATH,filesep);  % strjoin doesn't add trailing filesep

    addpath(BW_PATH);
    
    % brainwave subfolder paths...
    MEX_PATH = strcat(BW_PATH,'mex');
    addpath(MEX_PATH);

    DOC_PATH = strcat(BW_PATH,'doc');
    addpath(DOC_PATH);

    defaultPrefsFile = sprintf('%sbw_prefs.mat', BW_PATH);
    externalPath = strcat(BW_PATH,'external',filesep);

    dirpath=strcat(externalPath,'topoplot');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: topoplot folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'NIfTI_20140122');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: NIfTI folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'dicm2nii');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: dicm2nii folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'YokogawaMEGReader_R1.04.00');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: YokogawaMEGReader_R1.04.00 folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'yokogawa2ctf');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: yokogawa2ctf is missing...\n');
    else
        addpath(dirpath);
    end

    % add path for tesslation code
    dirpath=strcat(externalPath,filesep,'MyCrustOpen070909');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: MyCrustOpen070909 folder is missing...\n');
    else
        addpath(dirpath);
    end   
    
    dirpath=strcat(externalPath,filesep,'mne-matlab',filesep,'matlab');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: mne-matlab folder is missing...\n');
    else
        addpath(dirpath);
    end    

    button_text = [0.6,0.25,0.1];   % orange
    
    button_fontSize = 10;
    heading_fontSize = 12;
    button_fontWt = 'bold';

    menu=figure('Name', 'BrainWave5','Position',[200 200 550 550],...
                'menubar','none','numbertitle','off', 'Color','white', 'CloseRequestFcn',@QUIT_CALLBACK);
    if ispc
        movegui(menu,'center');
    end
    
    logo=imread([BW_PATH,filesep,'BRAINWAVE_LOGO_2.png']);
    axes('parent',menu,'position',[0.1 0.02 0.9 0.75]);                  
    bh = image(logo);
    set(bh,'AlphaData',0.25);
    axis off;
    buttonHeight = 0.07;
    buttonWidth = 0.3;
    
    s = sprintf('Version: %.1f (%s)',BW_VERSION, RELEASE_DATE);
    uicontrol('Style','text','FontSize', 9,'FontWeight','normal','Units','Normalized','HorizontalAlignment','Left',...
        'Position',[0.11 0.02 0.5 0.04],'BackgroundColor','white','ForegroundColor',button_text,'string',s);

    uicontrol('Style','text','FontSize',heading_fontSize,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.1 0.87 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','MEG Preprocessing');

    uicontrol('Style','text','FontSize',heading_fontSize,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.58 0.87 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','MRI Preprocessing');
    
    uicontrol('Style','text','FontSize',heading_fontSize,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.1 0.54 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','Source Analysis');
    
    uicontrol('Style','text','FontSize',heading_fontSize,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.58 0.54 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','Data Viewers');

    %%%  MEG preprocessing

    dataEditor = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.81 buttonWidth buttonHeight],'String','Data Editor','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@DATA_EDITOR_CALLBACK);

    importData = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.7 buttonWidth buttonHeight],'String','Epoch Data','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_DATA_CALLBACK);
   
   %%% MRI Preprocessing
    mriImport = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.58 0.81 buttonWidth buttonHeight],'String','Import MRI','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@MRI_IMPORT_CALLBACK);
 
   importSurfaces = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.58 0.7 buttonWidth buttonHeight],'String','Import Surfaces','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_SURFACES_CALLBACK);
   
        %%% analysis

    dipolePlot = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.48 buttonWidth buttonHeight],'String','DataPlot / Dipole Fit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@DIPOLE_PLOT_CALLBACK);

    singleSubject =  uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.38 buttonWidth buttonHeight],'String','Beamforming (Single)','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SINGLE_SUBJECT_CALLBACK);

    groupAnalysis = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.28 buttonWidth buttonHeight],'String','Beamforming (Group)','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_IMAGE_CALLBACK);
    
    
    
    % visualization
    mriViewer = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.58 0.48 buttonWidth buttonHeight],'String','MRI Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@MRI_VIEWER_CALLBACK);

    surfaceViewer = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.58 0.38 buttonWidth buttonHeight],'String','Surface Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SURFACE_VIEWER_CALLBACK);
       
    imageViewer = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.58 0.28 buttonWidth buttonHeight],'String','4D Image Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMAGE_VIEWER_CALLBACK);

    quitButton = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.37 0.15 0.25 buttonHeight],'String','Quit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@QUIT_CALLBACK);

    if ~ismac && isunix
        set(importData,'BackgroundColor','white');
        set(dipolePlot,'BackgroundColor','white');
        set(singleSubject,'BackgroundColor','white');
        set(groupAnalysis,'BackgroundColor','white');
        set(dataEditor,'BackgroundColor','white');       
        
        set(mriImport,'BackgroundColor','white');
        set(mriViewer,'BackgroundColor','white');
        set(importSurfaces,'BackgroundColor','white');
        set(surfaceViewer,'BackgroundColor','white');
        set(imageViewer,'BackgroundColor','white');

        set(quitButton,'BackgroundColor','white');
    end


    % Menus
    FILE_MENU=uimenu('Label','File');
    uimenu(FILE_MENU,'label','Open Study...','Callback',@OPEN_STUDY_CALLBACK);
    uimenu(FILE_MENU,'label','Quit BrainWave','separator','on','Callback',@QUIT_CALLBACK);

    TOOLS_MENU=uimenu('Label','Tools');
    uimenu(TOOLS_MENU,'label','Virtual Sensor Analysis...','Callback',@GROUP_VS_CALLBACK);
    uimenu(TOOLS_MENU,'label','Combine CTF Datasets...','separator','on','Callback',@COMBINE_CALLBACK);
    uimenu(TOOLS_MENU,'label','Concatenate CTF Datasets...','Callback',@CONCAT_CALLBACK);
    
    HELP_MENU=uimenu('Label','Help');

    GUIDE_MENU = uimenu(HELP_MENU,'label','User Guides');
    uimenu(GUIDE_MENU,'label','QuickStart Guide...','Callback',@BW_GUIDE_CALLBACK);
    uimenu(GUIDE_MENU,'label','Dipole Fitting...','Callback',@DIPOLE_GUIDE_CALLBACK);
    uimenu(GUIDE_MENU,'label','Beamformer Analysis...','Callback',@BEAM_GUIDE_CALLBACK);
    uimenu(GUIDE_MENU,'label','Group Analysis...','Callback',@GROUP_GUIDE_CALLBACK);
    uimenu(HELP_MENU,'label','About Brainwave...','separator','on','Callback',@ABOUT_MENU_CALLBACK);

    
    function BW_GUIDE_CALLBACK(~,~)
               
        if 0   % to open README.md in gitlab instead of PDF  
          url = 'https://git.ccm.sickkids.ca/cheyne-lab/brainwave5/-/blob/master/README.md';
          web(url)        
        else
            file = sprintf('%s%sQuickStart_Guide.pdf', DOC_PATH, filesep);
            if ~ismac && isunix 
                cmd = sprintf('evince %s', file);
                system(cmd);
            else
                open(file)
            end
        end

    end

    function DIPOLE_GUIDE_CALLBACK(~,~)
        helpdlg('Coming soon...')
        % file = sprintf('%s%sXX_GUIDE.pdf', DOC_PATH, filesep);
        % if ~ismac && isunix 
        %     cmd = sprintf('evince %s', file);
        %     system(cmd);
        % else
        %     open(file)
        % end       
    end

    function BEAM_GUIDE_CALLBACK(~,~)
        helpdlg('Coming soon...')
        % file = sprintf('%s%sXX_GUIDE.pdf', DOC_PATH, filesep);
        % if ~ismac && isunix 
        %     cmd = sprintf('evince %s', file);
        %     system(cmd);
        % else
        %     open(file)
        % end       
    end

    function GROUP_GUIDE_CALLBACK(~,~)
        helpdlg('Coming soon...')
        % file = sprintf('%s%sXX_GUIDE.pdf', DOC_PATH, filesep);
        % if ~ismac && isunix 
        %     cmd = sprintf('evince %s', file);
        %     system(cmd);
        % else
        %     open(file)
        % end       
    end

    function OPEN_STUDY_CALLBACK(~,~)
        [name,path,~] = uigetfile({'*STUDY.mat','BrainWave Study (*STUDY.mat)';'*.mat','All files (*.mat)'},'Select Study ...');
        if isequal(name,0)
            return;
        end
        studyFileFull = fullfile(path,name);

        bw_group_analysis(studyFileFull);

    end    

    function GROUP_VS_CALLBACK(~,~)
        bw_plot_dialog;
    end

    function COMBINE_CALLBACK(~,~)    
        startPath = pwd;
        bw_combine_datasets(startPath);
    end

    function CONCAT_CALLBACK(~,~)    
        startPath = pwd;
        bw_concatenate_datasets(startPath);
    end

    function ABOUT_MENU_CALLBACK(~,~)       
       bw_about;       
    end

    % BUTTON callbacks 
    % changed to save parent handles for quiting 


    function IMPORT_DATA_CALLBACK(~,~)       
        bw_epoch_data;
        fig_handles(end+1) = gcf;
    end

   function DATA_EDITOR_CALLBACK(~,~)
        bw_dataEditor;
        fig_handles(end+1) = gcf;
    end

    function DIPOLE_PLOT_CALLBACK(~,~)
        bw_dipoleFitGUI();
        fig_handles(end+1) = gcf;
    end
        
    function SINGLE_SUBJECT_CALLBACK(~,~)       
        bw_single_subject_analysis;
        fig_handles(end+1) = gcf;
    end

    function GROUP_IMAGE_CALLBACK(~,~)       
        bw_group_analysis([]);
        fig_handles(end+1) = gcf;
    end

    function MRI_IMPORT_CALLBACK(~,~)    
        [~, mriName] = bw_importMRI;
        if ~isempty(mriName)
            bw_MRIViewer(mriName);
            fig_handles(end+1) = gcf;
        end
    end
    
    function MRI_VIEWER_CALLBACK(~,~)       
        bw_MRIViewer;
        fig_handles(end+1) = gcf;
    end

    function SURFACE_VIEWER_CALLBACK(~,~)       
        bw_meshViewer;
        fig_handles(end+1) = gcf;
    end

    function IMAGE_VIEWER_CALLBACK(~,~)       
        bw_mip_plot_4D;
        fig_handles(end+1) = gcf;
    end

    function IMPORT_SURFACES_CALLBACK(~,~)                                       
        meshFile = bw_import_surfaces;               
        if ~isempty(meshFile)
            bw_meshViewer(meshFile);
            fig_handles(end+1) = gcf;
        end               
    end


    function QUIT_CALLBACK(~,~)   
        response = questdlg('Quit Brainwave?','BrainWave','Yes','No','No');
        if strcmp(response,'Yes')    
            delete(menu);
            if ~isempty(fig_handles)
                % remove invalid handles (window was already closed)
                idx = find(~ishandle(fig_handles));
                fig_handles(idx) = [];
                close(fig_handles);
            end
        end       
    end
       
end
