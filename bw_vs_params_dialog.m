% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% function [parsString applyAll] = vsParamsDlg(init_pars, coordType )
% D. Cheyne 2015
% Adapted from old version of group_vs plot to specify VS
% parameters for plotting
%
% Jan 2022 - rewrite for version 4.0 (D. Cheyne)
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [pos, ori, dsName, covDsName, label] = bw_vs_params_dialog(pos, ori, dsName, covDsName, label )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Edit VS parameters','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 800 250]);
   
        
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.78 0.6 0.15 0.22],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',12,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.78 0.25 0.15 0.22],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);


   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.15 0.8 0.25 0.15],'String','Position (cm)','FontSize',12,'enable','on', ...
       'BackGroundColor','white','foregroundcolor','black'); 

   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.8 0.25 0.15],'String','Orientation ','FontSize',12,'enable','on', ...
       'BackGroundColor','white','foregroundcolor','black'); 

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.03 0.7 0.1 0.15],'string','Convert MNI','BackgroundColor','white','FontSize',10,...
        'ForegroundColor','black','callback',@convertMNI_callback);

    s = sprintf('%.2f',pos(1));
    posXEdit=uicontrol('style','edit','units','normalized','position',...
          [0.15 0.7 0.06 0.15],'String',s, 'FontSize', 12,...
              'BackGroundColor','white');    
    s = sprintf('%.2f',pos(2));
    posYEdit=uicontrol('style','edit','units','normalized','position',...
          [0.22 0.7 0.06 0.15],'String',s, 'FontSize', 12,...
              'BackGroundColor','white');    
    s = sprintf('%.2f',pos(3));
    posZEdit=uicontrol('style','edit','units','normalized','position',...
          [0.3 0.7 0.06 0.15],'String', s, 'FontSize', 12,...
              'BackGroundColor','white');    
       
    oriXEdit=uicontrol('style','edit','units','normalized','position',...
          [0.45 0.7 0.06 0.15],'String', ori(1), 'FontSize', 12,...
              'BackGroundColor','white');    
    oriYEdit=uicontrol('style','edit','units','normalized','position',...
          [0.52 0.7 0.06 0.15],'String', ori(2), 'FontSize', 12,...
              'BackGroundColor','white');    
    oriZEdit=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.7 0.06 0.15],'String', ori(3), 'FontSize', 12,...
              'BackGroundColor','white');  
         
    uicontrol('style','text','units','normalized','horizontalalignment','right','position',...
        [0.03 0.38 0.15 0.15],'String','Dataset:','FontSize',12, ...
       'BackGroundColor','white','foregroundcolor','black'); 
    
    dsNameEdit = uicontrol('style','edit','units','normalized','HorizontalAlignment','left','position',...
          [0.2 0.4 0.4 0.15],'String', dsName, 'FontSize', 12,...
              'BackGroundColor','white');  
    function change_ds_callback(~,~)
        [loadpath] = uigetdir('*.ds','Select a dataset for VS calculation');
        if isequal(loadpath,0)
            return;
        end   
        [~, name, ext] = bw_fileparts( loadpath);      
        dsName = strcat(name, ext);         
        set(dsNameEdit,'string',dsName);
    end

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.62 0.4 0.1 0.15],'string','Select','BackgroundColor','white',...
        'FontSize',12,'ForegroundColor','blue','callback',@change_ds_callback);
          
    uicontrol('style','text','units','normalized','horizontalalignment','right','position',...
        [0.03 0.19 0.15 0.15],'String','Covariance Dataset:','FontSize',12, ...
       'BackGroundColor','white','foregroundcolor','black'); 
   
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.62 0.21 0.1 0.15],'string','Select','BackgroundColor','white',...
        'FontSize',12,'ForegroundColor','blue','callback',@change_covDs_callback);

    covDsNameEdit = uicontrol('style','edit','units','normalized','HorizontalAlignment','left','position',...
          [0.2 0.21 0.4 0.15],'String', covDsName, 'FontSize', 12,...
              'BackGroundColor','white');  
                  
    function change_covDs_callback(~,~)
        [loadpath] = uigetdir('*.ds','Select a dataset for covariance calculation');
        if isequal(loadpath,0)
            return;
        end   
        [~, name, ext] = bw_fileparts( loadpath);      
        covDsName = strcat(name, ext);      
        set(covDsNameEdit,'string',covDsName);
        
    end


    function convertMNI_callback(~,~)
        if isempty(dsName)
            s = sprintf('No dataset specified');
            errordlg(s);
            return;
        end
        [~, ~, ~, mri_path, ~] =  bw_parse_ds_filename(dsName);
        transformsFile = strcat(mri_path,filesep,'transforms.mat');
        
        if ~exist(transformsFile,'file')
            s = sprintf('Could not find transforms.mat file for this dataset');
            errordlg(s);
            return;    
        end
        transforms = load(transformsFile);

        mni_coord = [0 0 0];
        input = inputdlg({'MNI coordinate (mm)'},'Convert MNI Coordinate', [1 50], {num2str(mni_coord)});
        if isempty(input)
            return;
        end
        mni_coord = str2num(input{1});
              
        if isempty(transforms)
            return;
        end

        vox_meg = [mni_coord 1] * transforms.MNI_to_MEG;   
        s = sprintf('%.2f', vox_meg(1));
        set(posXEdit,'string', s);
        s = sprintf('%.2f', vox_meg(2));
        set(posYEdit,'string', s);
        s = sprintf('%.2f', vox_meg(3));
        set(posZEdit,'string', s);

    end


    uicontrol('style','text','units','normalized','horizontalalignment','right','position',...
        [0.03 0.01 0.15 0.15],'String','Label:','FontSize',12, ...
       'BackGroundColor','white','foregroundcolor','black'); 
   
    labelEdit = uicontrol('style','edit','units','normalized','HorizontalAlignment','left','position',...
          [0.2 0.04 0.4 0.15],'String', label, 'FontSize', 12,...
              'BackGroundColor','white');  

    function ok_callback(~,~)
        % update params
       
        string_value=get(posXEdit,'String');
        pos(1)=str2double(string_value);  
        string_value=get(posYEdit,'String');
        pos(2)=str2double(string_value);  
        string_value=get(posZEdit,'String');
        pos(3)=str2double(string_value);  
        
        string_value=get(oriXEdit,'String');
        ori(1)=str2double(string_value);  
        string_value=get(oriYEdit,'String');
        ori(2)=str2double(string_value);  
        string_value=get(oriZEdit,'String');
        ori(3)=str2double(string_value);      
        
        label = get(labelEdit, 'string');
        
        uiresume(gcf);
    end

    function cancel_callback(~,~)
        pos = [];
        ori = [];
        uiresume(gcf); 
    end

    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end
