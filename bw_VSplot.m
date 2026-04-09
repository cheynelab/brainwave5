function bw_VSplot(VS_ARRAY, params)       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_VSplot(VS_ARRAY, vs_options)
%
%   DESCRIPTION: creates a virtual sensor plot window - separate function 
%   that is derived from bw_make_vs_mex.  Note plot window holds  all params
%   necessary to save average and/or generate the single trial data for saving.
%
%   Dec, 2015 - replaces bw_plot_vs.m
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    if isempty(params.vs_parameters.plotLabel)
        groupLabel = 'Grand Average';
    else
        groupLabel = params.vs_parameters.plotLabel;
    end
    
    if isfield(params.vs_parameters,'groupLabel')
        filename = params.vs_parameters.groupLabel;
    else
        filename = 'Virtual Sensor';
    end

    % baseline should always be active for VS plots...
    params.beamformer_parameters.useBaselineWindow = 1;
    
    scrnsizes=get(0,'MonitorPosition');

    % persistent counter to move figure
    persistent plotcount;

    if isempty(plotcount)
        plotcount = 0;
    else
        plotcount = plotcount+1;
    end

    % tile windows
    width = 900;
    height = 450;
    start = round(0.4 * scrnsizes(1,3));
    bottom_start = round(0.7 * scrnsizes(1,4));

    inc = plotcount * 0.01 * scrnsizes(1,3);
    left = start+inc;
    bottom = bottom_start - inc;

    ylimits = []; % forces autoscale first time
    xlimits = []; % forces autoscale first time
    flipWaveforms = 0;
    
    if ( (left + width) > scrnsizes(1,3) || (bottom + height) > scrnsizes(1,4)) 
        plotcount = 0;
        left = start;
        bottom = bottom_start;
    end
    
    fh = figure('color','white','Position',[left,bottom,width,height], 'NumberTitle','off');
    if ispc
        movegui(fh,'center');
    end
    
    datacursormode(fh);
        
    BRAINWAVE_MENU=uimenu('Label','Brainwave');
        
    uimenu(BRAINWAVE_MENU,'label','Save VS Plot...','Callback',@save_vs_data_callback);
    uimenu(BRAINWAVE_MENU,'label','Add VS Plot...','Callback',@open_vs_callback);
    uimenu(BRAINWAVE_MENU,'label','Export VS data ...','Callback',@save_data_callback);
    
    PLOT_AVERAGE_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average','separator','on','Callback',@average_callback);
    PLOT_PLUSMINUS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average+PlusMinus','Callback',@plusminus_callback);
    PLOT_ALL_EPOCHS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Single trials','Callback',@all_epochs_callback);

    ERROR_BAR_MENU = uimenu(BRAINWAVE_MENU,'label','Show Standard Error','separator','on');
    uimenu(BRAINWAVE_MENU,'label','Change Plot Colour...','Callback',@plot_color_callback);
    uimenu(BRAINWAVE_MENU,'label','Flip Polarity','Callback',@flip_callback);

    ERROR_NONE = uimenu(ERROR_BAR_MENU,'label','None','checked','on','Callback',@plot_none_callback);
    ERROR_SHADED = uimenu(ERROR_BAR_MENU,'label','Shaded','Callback',@plot_shaded_callback);
    ERROR_BARS = uimenu(ERROR_BAR_MENU,'label','Bars','Callback',@plot_bars_callback);
          
    DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
   
    set(PLOT_AVERAGE_MENU,'checked','on');      
        

    %%%%%%%%%%%%%%%%%%
    % set defaults
    %%%%%%%%%%%%%%%%%%

    numSubjects = 1;
    bandwidth = VS_ARRAY{1}.filter; 
    timeVec = VS_ARRAY{1}.timeVec;
    dwel = timeVec(2) - timeVec(1);
    sampleRate = 1.0 / dwel; 

    plotAverage = 1;
    plotPlusMinus = 0;
    plotOverlay = 0;
    subject_idx = 1;
    
    vs_data = {};
    ave_group = [];
    labels = {};

    lineThickness = 0.8;
    fontSize = 12;

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    % moved edit controls to plot window
    %%%%%%%%%%%%%%%%%%%%%%%%%%%

    % filter

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.76 0.86 0.2 0.05],'String','Filter (Hz):','FontSize',10,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.76 0.805 0.1 0.05],'String','Highpass:','FontSize',10,'BackGroundColor','white');

    uicontrol('style','edit','units','normalized','position',...
        [0.82 0.81 0.05 0.05],'String', params.beamformer_parameters.filter(1),...
          'FontSize', 11, 'BackGroundColor','white','callback',@filter_edit_min_callback);
         function filter_edit_min_callback(src,~)
            string_value=get(src,'String');      
            fc = str2double(string_value);
            if ( fc > params.beamformer_parameters.filter(2) || fc < bandwidth(1) || fc > bandwidth(2))
                fprintf('Invalid filter range ...\n');
                set(src,'string',params.beamformer_parameters.filter(1));
                return;
            end
            params.beamformer_parameters.filter(1) = fc;
            processData;
            updatePlot;
         end

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.88 0.805 0.1 0.05],'String','Lowpass:','FontSize',10,'BackGroundColor','white');

    uicontrol('style','edit','units','normalized','position',...
        [0.93 0.81 0.05 0.05],'String',params.beamformer_parameters.filter(2),...
        'FontSize', 11, 'BackGroundColor','white','callback',@filter_edit_max_callback);
    
        function filter_edit_max_callback(src,~)
            string_value=get(src,'String');      
            fc = str2double(string_value);
            if ( fc < params.beamformer_parameters.filter(1) || fc < bandwidth(1) || fc > bandwidth(2))
                fprintf('Invalid filter range ...\n');
                set(src,'string',params.beamformer_parameters.filter(2));
                return;
            end
            params.beamformer_parameters.filter(2) = fc;
            processData;
            updatePlot;
         end    

    % baseline

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.76 0.7 0.2 0.05],'String','Baseline Correction (s):','FontSize',10,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.78 0.645 0.1 0.05], 'String','Start:','FontSize',10,'BackGroundColor','white');
    
    uicontrol('style','edit','units','normalized','position', ...
        [0.82 0.65 0.05 0.05], 'String', params.beamformer_parameters.baseline(1), 'FontSize', 10, 'BackGroundColor','white','callback',@baseline_edit_min_callback);
        
        function baseline_edit_min_callback(src,~)
            string_value=get(src,'String');      
            b=str2double(string_value);
            if ( b > params.beamformer_parameters.baseline(2) || b < timeVec(1)|| b > timeVec(end) )
                fprintf('Invalid baseline range ...\n');
                set(src,'string',params.beamformer_parameters.baseline(1));
                return;
            end
            params.beamformer_parameters.baseline(1) = b;
            processData;
            updatePlot;
        end
    
    uicontrol('style','text','units','normalized','position',...
        [0.88 0.645 0.05 0.05],'String','End:','FontSize',11,'BackGroundColor','white');
    uicontrol('style','edit','units','normalized','position',...
        [0.93 0.65 0.05 0.05],'String', params.beamformer_parameters.baseline(2), 'FontSize', 10, 'BackGroundColor','white','callback',@baseline_edit_max_callback);
        function baseline_edit_max_callback(src,~)
            string_value=get(src,'String');      
            b=str2double(string_value);
            if ( b < params.beamformer_parameters.baseline(1) || b < timeVec(1)|| b > timeVec(end) )
                fprintf('Invalid baseline range ...\n');
                set(src,'string',params.beamformer_parameters.baseline(2));
                return;
            end
            params.beamformer_parameters.baseline(2) = b;
            processData;
            updatePlot;
        end

     % time range
     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.76 0.55 0.2 0.05],'String','Time Range (s):','FontSize',10,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.78 0.495 0.1 0.05], 'String','Start:','FontSize',10,'BackGroundColor','white');
    
    uicontrol('style','edit','units','normalized','position', ...
        [0.82 0.5 0.05 0.05], 'String', timeVec(1), 'FontSize', 10, 'BackGroundColor','white','callback',@timeRange_edit_min_callback);
        
        function timeRange_edit_min_callback(src,~)
            string_value=get(src,'String');      
            b = str2double(string_value);
            if ( b > xlimits(2) || b < timeVec(1)|| b > timeVec(end) )
                fprintf('Invalid time range ...\n');
                set(src,'string',xlimits(1) );
                return;
            end
            xlimits(1) = b;
            updatePlot;
        end
    
    uicontrol('style','text','units','normalized','position',...
        [0.88 0.495 0.05 0.05],'String','End:','FontSize',11,'BackGroundColor','white');
    uicontrol('style','edit','units','normalized','position',...
        [0.93 0.5 0.05 0.05],'String', timeVec(end), 'FontSize', 10, 'BackGroundColor','white','callback',@timeRange_edit_max_callback);
        function timeRange_edit_max_callback(src,~)
            string_value=get(src,'String');      
            b = str2double(string_value);
            if ( b < xlimits(1) || b < timeVec(1)|| b > timeVec(end) )
                fprintf('Invalid time range ...\n');
                set(src,'string',xlimits(2));
                return;
            end
            xlimits(2) = b;
            updatePlot;
        end       

     % amplitude range
     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.76 0.4 0.2 0.05],'String','Amplitude Range (s):','FontSize',10,'Fontweight','bold','BackGroundColor','white');

     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.78 0.345 0.1 0.05], 'String','Min:','FontSize',10,'BackGroundColor','white');
     AMP_RANGE_MIN_EDIT = uicontrol('style','edit','units','normalized','position',...
        [0.82 0.35 0.05 0.05],'String', 0, 'FontSize', 10, 'BackGroundColor','white','callback',@ampRange_edit_min_callback);
   
        function ampRange_edit_min_callback(src,~)
            string_value=get(src,'String');      
            b = str2double(string_value);
            if ( b > ylimits(2) )
                fprintf('Invalid time range ...\n');
                set(src,'string',ylimits(1));
                return;
            end
            ylimits(1) = b;
            updatePlot;
        end         
    
     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.88 0.345 0.1 0.05], 'String','Min:','FontSize',10,'BackGroundColor','white');
     AMP_RANGE_MAX_EDIT = uicontrol('style','edit','units','normalized','position',...
        [0.93 0.35 0.05 0.05],'String', 0, 'FontSize', 10, 'BackGroundColor','white','callback',@ampRange_edit_max_callback);
   
        function ampRange_edit_max_callback(src,~)
            string_value=get(src,'String');      
            b = str2double(string_value);
            if ( b < ylimits(1) )
                fprintf('Invalid time range ...\n');
                set(src,'string',ylimits(2));
                return;
            end
            ylimits(2) = b;
            updatePlot;
        end         

    uicontrol('style','pushbutton','units','normalized','fontSize',9,'position',...
        [0.78 0.28 0.1 0.04],'string','Autoscale','callback',@autoScale_callback);
        function autoScale_callback(~,~)
            ylimits = [];
            updatePlot;         
        end

     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.76 0.18 0.1 0.05], 'String','Line Thickness:','FontSize',10,'Fontweight','bold','BackGroundColor','white');
     uicontrol('style','edit','units','normalized','position',...
        [0.86 0.186 0.05 0.05],'String', lineThickness, 'FontSize', 10, 'BackGroundColor','white','callback',@line_thickness_callback);
   
        function line_thickness_callback(src,~)
            lineThickness = str2double(get(src,'String'));    
            updatePlot;
        end         
    
     uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.76 0.11 0.1 0.05], 'String','Font Size:','FontSize',10,'Fontweight','bold','BackGroundColor','white');
      uicontrol('style','edit','units','normalized','position',...
        [0.86 0.116 0.05 0.05],'String', fontSize, 'FontSize', 10, 'BackGroundColor','white','callback',@fontSize_callback);
   
    function fontSize_callback(src,~)
            fontSize = str2double(get(src,'String'));    
            updatePlot;
        end         
    



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

    initialize_subjects;
   
    function initialize_subjects() 
        
       [~, numSubjects] = size(VS_ARRAY);
       if numSubjects == 1
            set(ERROR_BAR_MENU,'enable','off');
            subject_idx = 1;
        else
            subject_idx = 0;
       end  
        
        for k=1:numSubjects
            labels{k} = cellstr(VS_ARRAY{k}.label); 
        end

        % rebuild data menu
        if exist('DATA_SOURCE_MENU','var')
            delete(DATA_SOURCE_MENU);
            clear DATA_SOURCE_MENU;
        end    
        DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
        for k=1:numSubjects
            uimenu(DATA_SOURCE_MENU,'Label',char(labels{k}),'Callback',@data_menu_callback);   
        end

        if (numSubjects > 1)
            plotOverlay = 1;        % make overlay default
            s = sprintf('%s', groupLabel);
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','off',...
                'separator','on','Callback',@data_menu_callback);        
            s = sprintf('Overlay');
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on',...edit 
                'separator','on','Callback',@data_menu_callback);        
        else
             % uncheck all menus
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
        end

        vs_data = {numSubjects};    
        numSamples = length(timeVec);
        ave_group = zeros(numSubjects,numSamples);

        for k=1:numSubjects
            vs_data{k} = VS_ARRAY{k}.vs_data';

            % check for single trial data
            if size(vs_data{k},1) == 1
                set(PLOT_ALL_EPOCHS_MENU,'enable','off');
                set(PLOT_PLUSMINUS_MENU,'enable','off');
            end
        end
        
    end
    
    % ** version 3.6 - add option to load another subject / condition
    function open_vs_callback(~,~)
        [name,path,~] = uigetfile('*.mat','Select a VS .mat file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);
       
        t = load(infile);
        
        % read old format...(needs testing)
        if ~isfield(t,'VS_ARRAY')
            fprintf('This does not appear to be a BrainWave VS data file\n');
            return;
        end
        
        % check for same time base - use original VS for params?
        
        t_timeVec = t.VS_ARRAY{1}.timeVec;
        if any(t_timeVec~=timeVec)
            beep();
            fprintf('VS plots have different time bases\n');
            return;
        end
        
        for k=1:size(t.VS_ARRAY,2)
            VS_ARRAY{numSubjects+k} = t.VS_ARRAY{k};  
        end
        initialize_subjects;  
        updatePlot;        
        
     end    


    % callbacks
    
    function data_menu_callback(src,~)      
        subject_idx = get(src,'position');
        
        % if subject_idx == 0 plot average
        if subject_idx == numSubjects + 1
            subject_idx = 0;   
            plotOverlay = 0;
            set(ERROR_BAR_MENU,'enable','on');
        elseif subject_idx == numSubjects + 2
            subject_idx = 0;   
            plotOverlay = 1;
        else
            plotOverlay = 0;
            set(ERROR_BAR_MENU,'enable','off');
        end
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        
        set(src,'Checked','on');
        processData;
        updatePlot;
        
    end
    

    function average_callback(src,~)  
        plotAverage = true;
        plotPlusMinus = false;
        
        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        
        processData;
        updatePlot;     
    end

    function plusminus_callback(src,~)  
        plotPlusMinus = true;
        plotAverage = false;

        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_AVERAGE_MENU,'Checked','off');

        processData;
        updatePlot;     
    end

    function all_epochs_callback(src,~)  
        plotAverage = false;
        plotPlusMinus = false;
       
        set(src,'Checked','on');
        set(PLOT_AVERAGE_MENU,'Checked','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        
        processData;
        updatePlot;     
    end

   function plot_color_callback(~,~) 
        newColor = uisetcolor;
        if size(newColor,2) == 3
            params.vs_parameters.plotColor = newColor;
        end        
        updatePlot;
   end

   function flip_callback(src,~) 
        flipWaveforms = ~flipWaveforms;
        
        if flipWaveforms
            set(src,'Checked','on');
        else       
            set(src,'Checked','off');
        end
        updatePlot;
   end

   function plot_none_callback(src,~) 
        params.vs_parameters.errorBarType = 0;
        set(src,'Checked','on');
        set(ERROR_SHADED,'Checked','off');
        set(ERROR_BARS,'Checked','off');
        
        updatePlot;
   end

   function plot_bars_callback(src,~) 
        params.vs_parameters.errorBarType = 1;
        set(src,'Checked','on');
        set(ERROR_NONE,'Checked','off');
        set(ERROR_SHADED,'Checked','off');
        
        updatePlot;
   end

   function plot_shaded_callback(src,~) 
        params.vs_parameters.errorBarType = 2;
        set(src,'Checked','on');
        set(ERROR_NONE,'Checked','off');
        set(ERROR_BARS,'Checked','off');
        
        updatePlot;
   end


   function save_data_callback(~,~)
       
        [name,path,idx] = uiputfile({'*.mat','MAT-file (*.mat)';'*.txt','ASCII file (*.txt)';},...
                    'Export virtual sensor data to:');
        if isequal(name,0)
            return;
        end
        
        filename = fullfile(path,name);
                
        if idx == 1
            saveMatFile = true;
        else
            saveMatFile = false;
        end

        % format for matfile 
        % for n subjects / voxels
        % vsdata.subject{n}.timeVec = 1D array of latencies (nsamples x 1)
        % vsdata.subject{n}.trials = 3D array of vs data (ntrials x nsamples)
        % vsdata.subject{n}.label = original plot label

 
        % ensure current params applied 
        processData;
       
        saveAll = 1;
        % if displaying a single subject otion to save only that data
        if (subject_idx >  0)              
           r = questdlg('Save data for selected subject only?','BrainWave','Save single subject','Save all subjects','Save single subject');
           if strcmp(r,'Save single subject')
               saveAll = 0;
           end
        end

        % ver 4.2  - option to save data with flipped polarity
        polarity = 1.0;
        if flipWaveforms             
           r = questdlg('Save data with flipped polarity?','BrainWave','Save flipped','Save original','Save original');
           if strcmp(r,'Save flipped')
               polarity = -1.0;
           end
        end

        if ~saveAll
           % save this subject's data...           
           data = vs_data{subject_idx};
           data = data * polarity;
           
           % save in transposed in format = 1st column is timeVec, 2nd column is trial1...

           fprintf('Saving virtual sensor data to file %s\n', filename);      
          
           if saveMatFile 
                vsdata.subjects{1}.timeVec = timeVec;
                vsdata.subjects{1}.label = VS_ARRAY{1}.plotLabel;
                vsdata.subjects{1}.data = single(data');    % save single precision     
                save(filename,'-struct','vsdata');
           else
                fid = fopen(filename,'w');
                for k=1:size(data,2)
                    fprintf(fid, '%.4f', timeVec(k) );
                    for j=1:size(data,1)
                        fprintf(fid, '\t%8.4f', data(j,k) );
                    end   
                    fprintf(fid,'\n');
                end
                fclose(fid);                                                
            end
        else
            % save multi-subject (voxel) data...
           
            if saveMatFile   
                fprintf('Saving virtual sensor data to file %s\n', filename); 
                for k=1:numSubjects                    
                    data = vs_data{k}; 
                    vsdata.subjects{k}.timeVec = timeVec;
                    vsdata.subjects{k}.label = VS_ARRAY{k}.plotLabel;
                    vsdata.subjects{k}.data = single(data');                 
                end
                save(filename,'-struct','vsdata');
            else
                % put ascii data in separate files but don't overwrite 
                for k=1:numSubjects
                    data = vs_data{k};
                    [path, name, ~] = bw_fileparts(filename); 
                    tname = sprintf('%s_%s.txt', name, char(labels{k}));
                    tFileName = fullfile(path,tname);
                    fprintf('Saving virtual sensor data to file %s\n', tFileName); 
                    fid = fopen(tFileName,'w');
                    for t=1:size(data,2)
                        fprintf(fid, '%.4f', timeVec(t) );
                        for j=1:size(data,1)
                            fprintf(fid, '\t%8.4f', data(j,t) );
                        end   
                        fprintf(fid,'\n');
                    end
                    fclose(fid);     
                end                  
            end
     
        end
   end

    % save data in re-loadable .mat file in BW format...
    function save_vs_data_callback(~,~)      
              
        defName = 'vs_plot.mat';
        [name,path,~] = uiputfile('*.mat','Select Name for VS data file:',defName);
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        
        fprintf('Saving VS data to file %s\n', outFile);
        
        % save currently displayed image (groupLabel not used?)
        % added save file name for plot titles 
        plotName = name(1:end-4);
        params.vs_parameters.groupLabel = plotName;
        set(fh,'Name',plotName);
        
        save(outFile,'VS_ARRAY','params', 'groupLabel');            

    end

    processData;
    updatePlot;

    function processData
        
        % reload original data
        for k=1:numSubjects
            vs_data{k} = VS_ARRAY{k}.vs_data';
        end
        
        % filter and offset removal
        for k=1:numSubjects            
            data = vs_data{k};
            if (~plotAverage || params.vs_parameters.plotAnalyticSignal) && subject_idx > 0 && params.vs_parameters.subtractAverage
               fprintf('subtracting average from single trials...\n');
               ave_data = mean(data,1);     
               for j=1:size(data,1)
                    data(j,:) = data(j,:) - ave_data;
               end
            end
            
            % filter if this is original bandwidth
            if params.beamformer_parameters.filter(1) ~= bandwidth(1) || params.beamformer_parameters.filter(2) ~= bandwidth(2)
                fprintf('filtering data...\n');
                for j=1:size(data,1)
                    data(j,:) = bw_filter(data(j,:)',  sampleRate,  params.beamformer_parameters.filter, 4,  params.beamformer_parameters.useReverseFilter);                  
                end
            end
            
            % if plot hilbert amplitude apply to the single trials
            % then compute average
            
            if params.vs_parameters.plotAnalyticSignal
                for j=1:size(data,1)               
                   h = hilbert( data(j,:) );
                   data(j,:) = abs(h);     
                end      
            end    
                                
            vs_data{k} = data;       
                        
        end
    end

    function updatePlot
             
        
        subplot(1,10,[1 8]);

        % prepare data for plotting....
        
        if (subject_idx >  0)     
            % plot single subject 
            plotLabel = VS_ARRAY{subject_idx}.plotLabel;    
            start = subject_idx;
            finish = subject_idx;
        else
            plotLabel = groupLabel;    
            start = 1;
            finish = numSubjects;
        end
       
        for k=start:finish
           
            % get data for subject k          
            trial_data = vs_data{k};         
            ave = mean(trial_data,1);     
            if plotPlusMinus   
               nr = (floor(size(trial_data,1)/2) * 2);
               oddTrials = 1:2:nr;
               tdata = trial_data(1:nr,:);  % make sure we have even # of trials
               tdata(oddTrials,:) = tdata(oddTrials,:) * -1.0;   
               pm_ave = mean(tdata,1);
            end
            
            % apply baseline correction to averages only
            % this can be set to params setting - doesn't matter if we do
            % it again for plots..
            if params.beamformer_parameters.useBaselineWindow
                startSample = round( ( params.beamformer_parameters.baseline(1) - timeVec(1)) / dwel) + 1;
                endSample = round( ( params.beamformer_parameters.baseline(2) - timeVec(1)) / dwel) + 1;
                b = mean( ave(startSample:endSample) );               
                ave = ave - b;   
            end
            
            if plotPlusMinus   
                startSample = round( ( params.beamformer_parameters.baseline(1) - timeVec(1)) / dwel) + 1;
                endSample = round( ( params.beamformer_parameters.baseline(2) - timeVec(1)) / dwel) + 1;
                b = mean( pm_ave(startSample:endSample) );               
                pm_ave = pm_ave - b;              
                pm_group(k,:) = pm_ave;  % pm ave for this subject
            end      
            
            % grand average data across subjects
            ave_group(k,:) = ave;  % ave for this subject
            if k==start
                trial_group = trial_data;          
            else
                trial_group = [trial_group; trial_data];
            end
        end
        
        if (subject_idx >  0)     
            if plotAverage    
                plot_data = ave;
            elseif plotPlusMinus
                plot_data = [ave; pm_ave];
            else
                plot_data = trial_data;
            end
        else
            if plotOverlay
                plot_data = ave_group;
            elseif plotAverage
                plot_data = mean(ave_group,1);
            elseif plotPlusMinus
                plot_data = [mean(ave_group,1); mean(pm_group,1)];
            else
                plot_data = trial_group;
            end
        end
                   
        % plot data ...
        
        if flipWaveforms
            plot_data = plot_data .* -1.0;
        end
        
        s = sprintf('%s (%g to %g Hz)', filename, params.beamformer_parameters.filter(1),  params.beamformer_parameters.filter(2));
        
        set(fh,'Name',s);

        if params.vs_parameters.errorBarType > 0 && plotAverage && subject_idx == 0 && plotOverlay == 0
            
            % compute variance across subjects
            stderr = std(ave_group,1) ./sqrt(numSubjects); 
            
            if params.vs_parameters.errorBarType == 1
                % zero values between steps
                err_step = round( params.vs_parameters.errorBarInterval / dwel);
                stderr( find( mod( 1:length(stderr), err_step ) > 0 ) ) = NaN;   

                errorbar(timeVec, plot_data, stderr,'color', params.vs_parameters.plotColor, 'CapSize', params.vs_parameters.errorBarWidth);

                
            elseif params.vs_parameters.errorBarType == 2      
                uplim=plot_data+stderr;
                lolim=plot_data-stderr;
                filledValue=[uplim fliplr(lolim)]; %depends on column type (needs to plot forward, then back to start before fill/patch)
                timeValue=[timeVec; flipud(timeVec)]; 

                h1=fill(timeValue,filledValue,params.vs_parameters.plotColor);
                set(h1,'FaceAlpha',0.5,'EdgeAlpha',0.5,'EdgeColor',params.vs_parameters.plotColor);
                hold on
                ph = plot(timeVec,plot_data, 'color', params.vs_parameters.plotColor);
                hold off
            end
            
        else
            if size(plot_data,1) == 1
                ph = plot(timeVec, plot_data, 'color', params.vs_parameters.plotColor); % apply color only if not plotting plus/ minus
            else
                ph = plot(timeVec, plot_data);                 
            end

        end

        set(ph,'linewidth',lineThickness);

        % adjust scales
        if isempty(xlimits)
            xlimits = [timeVec(1) timeVec(end)];
        end    
        xlim(xlimits);
        
        % autoscale first time only
        % avoid end effects by 10% for scaling
        if isempty(ylimits)
            num2plot  = size(plot_data,1);
            endpts = round(0.1*size(timeVec,1));
            mx = 0.0;
            for k=1:num2plot
                p = abs(plot_data(k,endpts:end-endpts));
                if max(abs(p)) > mx
                    mx = max(abs(p));
                end
            end
            
            ylimits = [-mx*1.2 mx*1.2];
        end
       
        ylim(ylimits);

        set(AMP_RANGE_MIN_EDIT,'string',ylimits(1));
        set(AMP_RANGE_MAX_EDIT,'string',ylimits(2));
       
        % annotate plot       
        if (params.vs_parameters.pseudoZ)   
            dataUnits = 'Pseudo-Z';
        else
            dataUnits = 'Moment (nAm)';
        end
        xlabel('Time (sec)');
        if params.vs_parameters.rms
            ytxt = strcat(dataUnits, ' (RMS)');
        else
            ytxt = dataUnits ;
        end
        ylabel(ytxt);


        legStr = {};
        plotTitle = plotLabel;
        
        if plotPlusMinus && ~plotOverlay
            legend('average','plus-minus average');
        else
            if plotOverlay
                plotTitle = sprintf('Overlay');
                for k=1:numSubjects
                    legStr(k) = labels{k};
                end
            else
                if subject_idx > 0
                    legStr = labels{subject_idx};
                else
                    s = sprintf('Average (n=%d)', numSubjects);
                    legStr = {s};
                end        
            end
        end

        tt = legend(legStr);
        set(tt,'Interpreter','none','AutoUpdate','off','Location','NorthWest');
        

        ax = gca;
        set(ax,'FontSize',fontSize);
        
        % draw axes
        ax_bb = axis;
        line_h1 = line([0 0],[ax_bb(3) ax_bb(4)]);
        set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax_bb(3) && vertLineVal < ax_bb(4)
            line_h2 = line([ax_bb(1) ax_bb(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        tt = title(plotTitle);
        
        set(tt,'Interpreter','none');      

    end


end



