%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       BW_PLOT_TFR
%
%   function bw_plot_tfr(TFR_DATA, plotTimeCourse)
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   D. Cheyne, July, 2011
%  - replaces functionality in bw_make_vs_mex for computing TFR and
%  plotting it
%  - needs to return the TFR data for grand averaging ...
%
%  D. Cheyne, Sept, 2011 
%   modified to take all parameters in TFR_DATA and update plot - this will allow adding 
%   more options in future.  Can also take data from reading struct from
%   file
%
%  D. Cheyne, Nov 2011
%   major changes.  - plotMode replaced with plotType and plotUnits
%                   - TFR routine creates basic data types and saves power
%                   and mean and phase so that plotting routine can convert
%                   between them without recomputing the transform. Added
%                   new menus to do this and option to plot in dB 
%
%  D. Cheyne, Jan, 2012  - make plotTimeCourse passed option                   
%  D. Cheyne, May, 2012  - added option to plot error bars    
%
%               Nov 2012 - Vers 2.2 - major changes for plotting
%               multi-subject data
%  D. Cheyne, March 2024 - added option to plot absolute power
% 
%  update Aug 2024 - moved edit fields to main window
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_plot_tfr(TFR_ARRAY, plotTimeCourse, groupLabel, filename)
    if ~exist('plotTimeCourse','var')
        plotTimeCourse = 0;
    end

    if ~exist('groupLabel','var')
        groupLabel = 'Group Average';
    end 
    
    if ~exist('filename','var')
        filename = 'Time-Frequency Plot';
    end 
    scrnsizes=get(0,'MonitorPosition');    
    fh = figure('Position',[scrnsizes(1,3)/3+200 scrnsizes(1,4)/2 850 640],'color','white', 'NumberTitle','off');  % make same size as waveform plot window!
    if ispc
        movegui(fh,'center');
    end
    BRAINWAVE_MENU=uimenu('Label','Brainwave');

    % uimenu(BRAINWAVE_MENU,'label','Plot parameters...','Callback',@change_baseline_callback);
    uimenu(BRAINWAVE_MENU,'label','Add TFR data...','Callback',@open_tfr_callback);
    uimenu(BRAINWAVE_MENU,'label','Save TFR data...','Callback',@save_tfr_data_callback);
    SAVE_TIMECOURSE_MENU = uimenu(BRAINWAVE_MENU,'label','Export Time Courses ...','Callback',@save_timecourse_callback);

    COLOR_MENU = uimenu(BRAINWAVE_MENU,'label','Change Plot Colour','enable','off','separator','on', 'Callback',@plot_color_callback);
    uimenu(BRAINWAVE_MENU,'label','Change Line Thickness', 'Callback',@thickness_callback);
    uimenu(BRAINWAVE_MENU,'label','Change Font Size', 'Callback',@fontsize_callback);
    COLORMAP_MENU = uimenu(BRAINWAVE_MENU,'label', 'Change Colormap','enable','on');
    COLOR_JET = uimenu(COLORMAP_MENU, 'label', 'Jet', 'checked','on','Callback',@plot_jet_callback);
    COLOR_PARULA = uimenu(COLORMAP_MENU, 'label', 'Parula', 'Callback',@plot_parula_callback);
    COLOR_GRAY = uimenu(COLORMAP_MENU, 'label', 'Gray', 'Callback',@plot_gray_callback);
    COLOR_HOT = uimenu(COLORMAP_MENU, 'label', 'Hot', 'Callback',@plot_hot_callback);
    COLOR_COOL = uimenu(COLORMAP_MENU, 'label', 'Cool', 'Callback',@plot_cool_callback);
  
    ERROR_BAR_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Standard Error','separator','on', 'enable','off');

    ERROR_NONE = uimenu(ERROR_BAR_MENU,'label','None','checked','on','Callback',@plot_none_callback);
    ERROR_SHADED = uimenu(ERROR_BAR_MENU,'label','Shaded','Callback',@plot_shaded_callback);
    ERROR_BARS = uimenu(ERROR_BAR_MENU,'label','Bars','Callback',@plot_bars_callback);
    
    DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');


    numSubjects = 1;
   
    subject_idx = 1;
    timeCourse = [];
    plotOverlay = 0;
    
    plotColor = [0 0 1];   
    labels = {};

    lineThickness = 0.8;
    fontSize = 10;
    
    dataUnits = TFR_ARRAY{1}.dataUnits;
    plotType = TFR_ARRAY{1}.plotType;   % 0 = total power, 1 = power-average, 2 = average, 3 = PLF
    plotUnits = TFR_ARRAY{1}.plotUnits;   % 0 =  power, 1 = dB, 2 = percent
    baseline = TFR_ARRAY{1}.baseline;
    timeVec = TFR_ARRAY{1}.timeVec;
    freqVec = TFR_ARRAY{1}.freqVec;
              
    freqRange = freqVec;  % freqRange can be changed in plot
    xlimits = [timeVec(1) timeVec(end)];  % timeRange can be changed in plot

    minVal = [];
    maxVal = [];
    GMinVal = [];
    GMaxVal = [];

    freqText = uicontrol('style','text','units','normalized','fontSize',14,'HorizontalAlignment','left',...
        'BackGroundColor','white','fontweight','bold','position',...
        [0.16 0.13 0.24 0.04],'string','');
                
    function setFrequencyText   
        if plotTimeCourse
            s = sprintf('%.1f to %.1f Hz ', freqRange(1), freqRange(end));
            set(freqText,'string',s);
            set(freqText,'visible','on');
      else
            set(freqText,'visible','off');
        end
    end

    baselineTxt = uicontrol('style','text','units','normalized','fontSize',12,'HorizontalAlignment','left','BackGroundColor','white','position',...
        [0.13 0.02 0.24 0.04],'string','');
                
    function setBaselineText                   
        s = sprintf('Baseline (%.2f to %.2f s)', baseline(1), baseline(2));
        set(baselineTxt,'string',s);
    end

    uicontrol('style','pushbutton','units','normalized','fontSize',10,'position',...
        [0.32 0.025 0.06 0.03],'string','Edit','callback',@setBaseline_callback);
    
    function setBaseline_callback(~,~)
        answer = inputdlg({'Start Time (s)'; 'End Time (s)'},'Set Baseline Range ',...
            [1 50; 1 50], {num2str(baseline(1)),num2str(baseline(2))});
        if isempty(answer)
            return;
        end
        mn = str2num(answer{1});
        mx = str2num(answer{2});
        if mn >= mx || mn < timeVec(1) || mx > timeVec(end)
            s = sprintf('Valid range is from %.2f s to %.2f s', timeVec(1),timeVec(2));
            errordlg(s);
            return;
        end
        baseline(1) = mn;
        baseline(2) = mx;
        updatePlot;
    end

    uicontrol('style','checkbox','units','normalized','fontSize',10,'fontweight','bold','BackGroundColor','white','position',...
        [0.64 0.025 0.2 0.04],'string','Plot as Time Course','value',plotTimeCourse,'callback',@plotTimeCourse_callback);
    function plotTimeCourse_callback(src,~)
        plotTimeCourse = get(src,'value');
        if plotTimeCourse && numSubjects == 1
            set(COLOR_MENU,'enable','on');
        else
            set(COLOR_MENU,'enable','off');
        end

        if plotTimeCourse && numSubjects > 1
            set(ERROR_BAR_MENU,'enable','on');
            set(SAVE_TIMECOURSE_MENU,'enable','on');
        else
            set(ERROR_BAR_MENU,'enable','off');
            set(SAVE_TIMECOURSE_MENU,'enable','off');
        end

        updatePlot;
    end
                  
    uicontrol('style','pushbutton','units','normalized','fontSize',10,'position',...
        [0.87 0.03 0.1 0.03],'string','Set Scale','callback',@setScale_callback);
    
    function setScale_callback(~,~)
        answer = inputdlg({'Minimum Value'; 'Maximum Value'},'Set Amplitude Range ',...
            [1 50; 1 50], {num2str(minVal),num2str(maxVal)}); 
        if isempty(answer)
            return;
        end
        mn = str2num(answer{1});
        mx = str2num(answer{2});
        if mn >= mx
            return;
        end
   
        GMinVal = mn;
        GMaxVal = mx;
        
        updatePlot;
    end
            

    uicontrol('style','pushbutton','units','normalized','fontSize',9,'position',...
        [0.1 0.94 0.12 0.04],'string','Freq. Range','callback',@setFreqRange_callback);
    
    function setFreqRange_callback(~,~)
        answer = inputdlg({'Min. Frequency (Hz)'; 'Max. Frequency (Hz)'},'Set Frequency Range ',...
            [1 50; 1 50], {num2str(freqRange(1)),num2str(freqRange(end))});
        if isempty(answer)
            return;
        end
        f1 = str2num(answer{1});
        f2 = str2num(answer{2});
        if f1 >= f2 || f1 < freqVec(1) || f2 > freqVec(end)
            s = sprintf('Valid range is from %.2f Hz to %.2f Hz', freqVec(1),freqVec(end));
            errordlg(s);
            return;
        end

        % find closest values in freqVec
        tmp = abs(f1-freqVec);
        [~, minidx] = min(tmp);
        freqRange(1) = freqVec(minidx);
        
        tmp = abs(f2-freqVec);
        [~, maxidx] = min(tmp);  
        freqRange(end) = freqVec(maxidx);
        
        fprintf('*** setting frequency range to %g Hz to %g Hz ***\n', f1, f2);
        freqRange = freqVec(minidx:maxidx);
        
        GMinVal = [];
        GMaxVal = [];
        
        updatePlot;

    end
        
    uicontrol('style','pushbutton','units','normalized','fontSize',9,'position',...
        [0.24 0.94 0.12 0.04],'string','Time Range','callback',@setTimeRange_callback);
    
    function setTimeRange_callback(~,~)
        answer = inputdlg({'Start Time (s)'; 'End Time (s)'},'Set Time Range ',...
            [1 50; 1 50], {num2str(xlimits(1)),num2str(xlimits(end))});
        if isempty(answer)
            return;
        end
        mn = str2num(answer{1});
        mx = str2num(answer{2});       
        
        xlimits = [mn mx];
        fprintf('*** setting time range to %g s to %g s ***\n', mn, mx);        
        
        updatePlot;

    end
        
    uicontrol('style','popupmenu','units','normalized','fontSize',9,'position',...
        [0.65 0.93 0.17 0.05],'string',{'Total Power'; 'Power-Average';'Average';'PLF'}, ...
        'value',plotType+1,'callback',@setPlotType_callback);
    
    function setPlotType_callback(src,~)
        plotType = get(src,'val') - 1;    
        % reset to autoscale if changing plot type
        GMaxVal = [];
        GMinVal = [];       
        updatePlot;
    end
        
    uicontrol('style','popupmenu','units','normalized','fontSize',9,'position',...
        [0.82 0.93 0.18 0.05],'string',{'Power (nAm^2)'; 'Power (dB)';'Percent Change';'Abs. Power (nAm^2)'}, ...
        'value',plotUnits+1,'callback',@setUnits_callback);
    
    function setUnits_callback(src,~)
        plotUnits = get(src,'val') - 1;    
        % reset to autoscale if changing plot type
        GMaxVal = [];
        GMinVal = [];       
        updatePlot;
    end

    function thickness_callback(~,~)
        answer = inputdlg({'Line Thickness'},'Set Line Thickness ',...
            [1 50], {num2str(lineThickness)});
        if isempty(answer)
            return;
        end
        lineThickness = str2num(answer{1});
        updatePlot;
    end

    function fontsize_callback(~,~)
        answer = inputdlg({'Font Size'},'Set Font Size ',...
            [1 50], {num2str(fontSize)});
        if isempty(answer)
            return;
        end
        fontSize = str2num(answer{1});
        updatePlot;
    end

    
    initialize_subjects;
   
    function initialize_subjects 
        
       [~, numSubjects] = size(TFR_ARRAY);
       if numSubjects == 1
            set(ERROR_BAR_MENU,'enable','off');
            subject_idx = 1;
        else
            subject_idx = 0;
        end  

        labels = {};

        % rebuild data menu
        if exist('DATA_SOURCE_MENU','var')
            delete(DATA_SOURCE_MENU);
            clear DATA_SOURCE_MENU;
        end
        
        DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
        
        for k=1:numSubjects
            labels{k} = cellstr(TFR_ARRAY{k}.label); 
        end
        
        for k=1:numSubjects
            uimenu(DATA_SOURCE_MENU,'Label',char(labels{k}),'Callback',@data_menu_callback);               
        end
        
        if (numSubjects > 1)

            uimenu(DATA_SOURCE_MENU,'Label',groupLabel,'Checked','off',...
                'separator','on','Callback',@data_menu_callback);
                        
            s = sprintf('All Virtual Sensors (overlay)');
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on','enable','on',...
                'separator','on','Callback',@data_menu_callback);    
            plotOverlay = 1;
        else
             % check single menu
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
            plotOverlay = 0;
        end
        GMinVal = [];
        GMaxVal = [];

        
    end
       
        % ** version 3.6 - add option to load another subject / condition
    function open_tfr_callback(~,~)
        [name,path,~] = uigetfile('*.mat','Select a TFR .mat file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);
       
        t = load(infile);
        
        % read old format...(needs testing)
        if ~isfield(t,'TFR_ARRAY')
            fprintf('This does not appear to be a BrainWave VS data file\n');
            return;
        end
        
        % check for same time base - use original VS for params?
        
        t_timeVec = t.TFR_ARRAY{1}.timeVec;
        if any(t_timeVec~=timeVec)
            beep();
            fprintf('TFR plots have different time bases\n');
            return;
        end
             
        
        t_freqVec = t.TFR_ARRAY{1}.freqVec;
        if any(t_freqVec~=freqVec)
            beep();
            fprintf('VS plots have different frequency ranges\n');
            return;
        end
        
                
        for k=1:size(t.TFR_ARRAY,2)
            TFR_ARRAY{numSubjects+k} = t.TFR_ARRAY{k};  
        end

        initialize_subjects;  
        updatePlot;        
        
     end    
    
    function data_menu_callback(src,~)      
        subject_idx = get(src,'position');
        
        plotOverlay = 0;
        % if subject_idx == 0 plot average
        if subject_idx == numSubjects + 1
            subject_idx = 0;
        end
        
        if subject_idx == numSubjects + 2
            subject_idx = 0;
            plotOverlay = 1;
        end
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        
        set(src,'Checked','on');
        
        updatePlot;
        
    end

    set(SAVE_TIMECOURSE_MENU,'enable','off');
    
    % can be added to defaults
    errorBarMode = 0;
    errorBarInterval = 0.1;
    errorBarWidth = errorBarInterval * 0.3;
    
    % global pointer to currently displayed data...
    tf_data = zeros(length(freqVec),length(timeVec));
    fdata = zeros(numSubjects, length(timeVec));
    
    plotColormap = jet;
    
    updatePlot;

    function plot_none_callback(src,~) 
        errorBarMode = 0;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_bars_callback(src,~) 
        errorBarMode = 1;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_shaded_callback(src,~) 
        errorBarMode = 2;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_color_callback(~,~) 
          newColor = uisetcolor;
          if size(newColor,2) == 3
              plotColor = newColor;
          end
          updatePlot;       
    end

    function enable_error_menus(str)
        set(ERROR_SHADED,'Checked',str);
        set(ERROR_NONE,'Checked',str);
        set(ERROR_BARS,'Checked',str);            
    end
 
    % Colormap
        
    function plot_jet_callback(src,~)
        plotColormap = jet;    
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_parula_callback(src,~)
        plotColormap = parula;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_gray_callback(src,~)
        plotColormap = gray;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_hot_callback(src,~)
        plotColormap = hot;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_cool_callback(src,~)
        plotColormap = cool;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function enable_colormap_menus(str)
        set(COLOR_PARULA,'Checked',str);
        set(COLOR_JET,'Checked',str);
        set(COLOR_GRAY,'Checked',str);            
        set(COLOR_HOT,'Checked',str);            
        set(COLOR_COOL,'Checked',str);            
    end

    function save_tfr_data_callback(~,~)      
        
        [name,path,~] = uiputfile('*.mat','Select Name for TFR file:');
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
                  
        % update to save currently displayed image
        
        % save currently displayed image
        % added save file name for plot titles 
        plotName = name(1:end-4);
        set(fh,'Name',plotName);
        
        % check if has single trial data - use option to save large .mat files
        if isfield(TFR_ARRAY,'TRIAL_MAGNITUDE')
            fprintf('Saving TFR data to file %s using -v7.3 switch...\n', outFile);
            save(outFile,'TFR_ARRAY','filename','-v7.3');            
        else
            save(outFile,'TFR_ARRAY', 'filename');            
            fprintf('Saving TFR data to file %s ...\n', outFile);
        end

    end

    function save_timecourse_callback(~,~)      
        if isempty(timeCourse) || ~plotTimeCourse
            return;
        end
             
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

       if saveMatFile   
            fprintf('Saving virtual sensor data to file %s\n', filename); 
            for k=1:numSubjects                    
                data = fdata(k,:); 
                vsdata.subjects{k}.timeVec = timeVec;
                vsdata.subjects{k}.label = TFR_ARRAY{k}.plotLabel;
                vsdata.subjects{k}.data = single(data');                 
            end
            save(filename,'-struct','vsdata');
        else
            % put ascii data in separate files but don't overwrite 
            for k=1:numSubjects
                data = fdata{k};
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

        % 
        % [name,path,~] = uiputfile({'*.txt','ASCII file (*.txt)';},...
        %             'Export time course data to:');
        % if isequal(name,0)
        %     return;
        % end
        % 
        % filename = fullfile(path,name);
        % fprintf('Saving time course to file %s\n', filename);
        % fid = fopen(filename,'w');
        % for k=1:size(timeCourse,1)
        %     fprintf(fid, '%.4f', timeVec(k) );
        %     fprintf(fid, '\t%8.4f', timeCourse(k) );
        %     fprintf(fid,'\n');
        % end

        % fclose(fid);

    end

    function updatePlot
        
        set(fh,'Name',filename);
        ph = [];

        % choose data to plotfunction 
        % we also do preprocessing and conversions here so 
        % that group error is correct etc.
      
        tf_data = zeros(length(freqRange),length(timeVec));   
        
        if (subject_idx >  0)
           
            if plotType == 0
                tf_data = TFR_ARRAY{subject_idx}.TFR;
            elseif plotType == 1
                tf_data = TFR_ARRAY{subject_idx}.TFR - TFR_ARRAY{subject_idx}.MEAN;
            elseif plotType == 2
                tf_data = TFR_ARRAY{subject_idx}.MEAN;
            elseif plotType == 3
                tf_data = TFR_ARRAY{subject_idx}.PLF;
            end
            
            % truncate to freq range
            [~, idx] = ismember(freqRange, freqVec);
            tf_data = tf_data(idx,:);      
            
            if plotType ~= 3
                tf_data = transformData(tf_data);
            end
            
            % time course is mean over frequency
            % no std err in this case...
            timeCourse = mean(tf_data)';

            plotLabel = TFR_ARRAY{subject_idx}.plotLabel;
            
        else
        
            % generate average TFR 
            ave_data = zeros(length(freqRange),length(timeVec));
           
            for k=1:numSubjects
                
               if plotType == 0
                    tf_data = TFR_ARRAY{k}.TFR;
                elseif plotType == 1
                    tf_data = (TFR_ARRAY{k}.TFR - TFR_ARRAY{k}.MEAN );
                elseif plotType == 2
                    tf_data = TFR_ARRAY{k}.MEAN;
                elseif plotType == 3
                    tf_data = TFR_ARRAY{k}.PLF;
               end
               
               % truncate to freq range
               [~, idx] = ismember(freqRange, freqVec);   
               tf_data = tf_data(idx,:);

               if plotType ~= 3
                    tf_data = transformData(tf_data);
                end
                
                % need time course collapsed over frequency for each subj
                fdata(k,:) = mean(tf_data)';
                
                % average the time-frequency data
                ave_data = ave_data + tf_data;
                tf_array{k} = tf_data;
            end
            
            tf_data = ave_data ./ numSubjects;
                       
            % compute mean image and time course + error           
            timeCourse = mean(tf_data)';
            
            stderr = std(fdata) ./sqrt(numSubjects);
           
            plotLabel = sprintf('%s', groupLabel);
                                  
        end
        
        % April 2012 - exclude boundaries from autoscaling 
        edgePts = ceil(0.1 * length(timeVec));
        trunc_data = tf_data(:,edgePts:end-edgePts);
       
        
        maxVal = max(max(abs(trunc_data)));
         
        if plotType == 3
            minVal = 0.0;       % if plotting PLF no negative range
        else
            minVal = -maxVal;
        end
        
        if plotType == 3
            unitLabel = sprintf('Phase-locking Factor');
        else
            switch plotUnits
                case 0
                    unitLabel = sprintf('Power (%s^2)',dataUnits);
                case 1
                    unitLabel = sprintf('Power (dB)');
                case 2
                    unitLabel = sprintf('Percent Change');
                case 3
                    unitLabel = sprintf('Absolute Power (%s^2)', dataUnits);
            end
        end
            
        if plotTimeCourse       

           subplot(1,1,1);
           if subject_idx == 0
               % plot time course of group data with error bars
               if plotOverlay
                    %  fdata contains individual timecourses...
                    ph = plot(timeVec, fdata);      
               else
                    if errorBarMode == 0                           
                        ph = plot(timeVec, timeCourse, 'color',plotColor);
                    elseif errorBarMode == 1
                        % create std error bars every errorBarInterval seconds
                        dwel = double(timeVec(2) - timeVec(1));
                        err_step = round(errorBarInterval / dwel);

                        % zero values between steps
                        stderr( find( mod( 1:length(stderr), err_step ) > 0 ) ) = NaN;   
                        ph = errorbar(timeVec, timeCourse, stderr, 'color',plotColor,'CapSize',errorBarWidth);    
 
                    elseif errorBarMode == 2
                        uplim=timeCourse'+stderr;
                        lolim=timeCourse'-stderr;
                        filledValue=[uplim fliplr(lolim)]; %depends on column type (needs to plot forward, then back to start before fill/patch)
                        timeValue=[timeVec; flipud(timeVec)]; 

                        h1=fill(timeValue,filledValue,plotColor);
                        set(h1,'FaceAlpha',0.5,'EdgeAlpha',0.5,'EdgeColor',plotColor);
                        hold on
                        ph = plot(timeVec,timeCourse, 'color',plotColor);
                        hold off
                    end
                end
                
            else 
                ph = plot(timeVec, timeCourse, 'color',plotColor);      
            end
        
            legStr = {};
            plotTitle = plotLabel;

            if plotOverlay 
                plotTitle = sprintf('All Sensors (Overlay)');
                for k=1:numSubjects
                    legStr(k) = labels{k};
                end
            else
                if subject_idx > 0
                    legStr = labels{subject_idx};
                else
                    legStr = {'Average'};
                end      
            end
            
            tt = legend(legStr);
            set(tt,'Interpreter','none','AutoUpdate','off');

            xlim(xlimits);

            if ~isempty(GMinVal)
                ylim([GMinVal GMaxVal]);    
            end
            % else autoscale
            
            xlabel('Time (s) ','FontSize',9);
            ylabel(unitLabel,'FontSize',9);
            ax = axis;
            set(gca,'fontsize',9);
            line_h1 = line([0 0],[ax(3) ax(4)]);
            set(line_h1, 'Color', [0 0 0]);
            vertLineVal = 0;
            
            if vertLineVal > ax(3) && vertLineVal < ax(4)
                line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
                set(line_h2, 'Color', [0 0 0]);
            end
            
             
            tb = axtoolbar;          
            set(tb,'Visible','off');    

            set(ph,'linewidth',lineThickness);
            ax = gca;
            set(ax,'FontSize',fontSize);      

            tt = title(plotTitle);
            set(tt,'Interpreter','none','FontSize',8);

        else
            if numSubjects > 0 && plotOverlay       
               tiledlayout('flow');
               for k=1:numSubjects
                    nexttile;
                    tf_data = tf_array{k};

                    if isempty(GMaxVal)
                        % autoscale each plot
                        edgePts = ceil(0.1 * length(timeVec));
                        trunc_data = tf_data(:,edgePts:end-edgePts);                  
                        % for multiple plots set to global max value ???
                        maxVal = max(max(abs(trunc_data)));
                        if plotType == 3
                            minVal = 0.0;       % if plotting PLF no negative range
                        else
                            minVal = -maxVal;
                        end
                    else
                        minVal = GMinVal;
                        maxVal = GMaxVal;
                    end

                    imagesc(timeVec, freqRange, tf_data, [minVal maxVal] );
                    colormap(plotColormap);
                    axis xy;    
                    set(gca,'FontSize',9);
                    tb = axtoolbar;
                    set(tb,'Visible','off');

                    xlim(xlimits);    
                    xlabel('Time (s) ');
                    ylabel('Freq (Hz)');
                    s = char(labels{k});

                    h = colorbar;
                    set(get(h,'YLabel'),'String',unitLabel,'FontSize',fontSize);
                    ax = gca;
                    set(ax,'FontSize',fontSize);                   
                    tt = title(s);
                    set(tt,'Interpreter','none','FontSize',8);
               end                                 

            else
                subplot(1,1,1);
                                     
                if isempty(GMaxVal)
                    % autoscale each plot
                    edgePts = ceil(0.1 * length(timeVec));
                    trunc_data = tf_data(:,edgePts:end-edgePts);                  
                    % for multiple plots set to global max value ???
                    maxVal = max(max(abs(trunc_data)));
                    if plotType == 3
                        minVal = 0.0;       % if plotting PLF no negative range
                    else
                        minVal = -maxVal;
                    end
                else
                    minVal = GMinVal;
                    maxVal = GMaxVal;
                end
                
                imagesc(timeVec, freqRange, tf_data, [minVal maxVal] );
                colormap(plotColormap);
                axis xy;  
                set(gca,'FontSize',9);

                h = colorbar;
                set(get(h,'YLabel'),'String',unitLabel,'FontSize',fontSize);
                                
                xlim(xlimits);
    
                xlabel('Time (s) ','FontSize',9);
                ylabel('Freq (Hz)','FontSize',9);
                
                tb = axtoolbar;
                set(tb,'Visible','off');
                ax = gca;
                set(ax,'FontSize',fontSize);

                tt = title(plotLabel);
                set(tt,'Interpreter','none','FontSize',8);
            end

        end

        clear trunc_data
        setBaselineText;
        setFrequencyText;
        
        % setPlotTypeText;
        
    end

    function transformed_data = transformData( data )
           
        % remove baseline power and convert units
        
        tidx = find(timeVec >= baseline(1) & timeVec <= baseline(2));

        for jj=1:size(data,1)
            t = data(jj,:);
            b = mean(t(tidx));

            if plotUnits == 0
                % baseline only  
                transformed_data(jj,:) = data(jj,:)-b;                                   
            elseif plotUnits == 1 
                % convert to dB scale  
                ratio = data(jj,:)/b;
                transformed_data(jj,:) = 10 * log10(ratio);
            elseif plotUnits == 2 
                % convert to percent change
                transformed_data(jj,:) = data(jj,:)-b;        
                transformed_data(jj,:) = ( transformed_data(jj,:)/b ) * 100.0;
            elseif plotUnits == 3  
                % raw power - no baseline
                transformed_data(jj,:) = data(jj,:);      
            end

            
        end
    end

end       





