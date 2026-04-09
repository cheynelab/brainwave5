%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function bw_editCTFMarkers( markerFileName )
% GUI to select a marker from CTF Marker.mrk file
%
% input:   name of a CTF MarkerFile (e.g., dsName/MarkerFile.mrk)
%
% returns: latencies and label for selected marker
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bw_combineCTFMarkers( dsName )
 
    markerFileName = strcat(dsName, filesep, 'MarkerFile.mrk');
    
    if ~exist(markerFileName,'file')
        errordlg('No marker file exists for this dataset.');
        return;
    end
    
    scrnsizes=get(0,'MonitorPosition');

    fg=figure('color','white','name','Combine Markers','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 250]);   
    
    Event_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.05 0.6 0.35 0.1],'String','No events','Backgroundcolor','white','fontsize',12,'value',1,'callback',@event_popup_callback);

        function event_popup_callback(src,~)
            menu_select=get(src,'value');
            markerTimes = markerData{menu_select};
            latencies1 = markerTimes(:,2);
            latencies = [latencies1; latencies2];

            str = sprintf('Total Number of Events = %d\n',length(latencies));   
            set(MarkerCountText,'String',str);

        end
   
    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.08 0.8 0.6 0.1],'String','Combine following markers:','Backgroundcolor','white','fontsize',12);

    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.08 0.45 0.6 0.1],'String','Marker Name (1):','Backgroundcolor','white','fontsize',12);

    MarkerCountText = uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.08 0.2 0.6 0.1],'String','Total Number of Events =','Backgroundcolor','white','fontsize',12);

    Event_popup2 = uicontrol('style','popup','units','normalized',...
    'position',[0.05 0.35 0.35 0.1],'String','No events','Backgroundcolor','white','fontsize',12,'value',1,'callback',@event_popup_callback2);

        function event_popup_callback2(src,~)
            menu_select=get(src,'value');
            markerTimes = markerData{menu_select};
            latencies2 = markerTimes(:,2);
            latencies = [latencies1; latencies2];

            str = sprintf('Total Number of Events = %d\n',length(latencies));   
            set(MarkerCountText,'String',str);

        end
   
    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.08 0.7 0.6 0.1],'String','Marker Name (2):','Backgroundcolor','white','fontsize',12);

    [names, markerData] = bw_readCTFMarkerFile(markerFileName);     
 
    set(Event_popup,'string',names);

    set(Event_popup2,'string',names);

    % initialize list to first marker
    set(Event_popup,'String',names,'value',1);  
    markerTimes = markerData{1};
    latencies1 = markerTimes(:,2);

    % initialize list to second marker
    set(Event_popup,'String',names,'value',2);  
    markerTimes = markerData{2};
    latencies2 = markerTimes(:,2);
    
    latencies = [latencies1; latencies2];

    str = sprintf('Total Number of Events = %d\n',numel(latencies));   
    set(MarkerCountText,'String',str);


    uicontrol('style','pushbutton','units','normalized','position',...
        [0.5 0.4 0.3 0.15],'string','Create Marker','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@save_callback);
    
    function save_callback(~,~)
        r = questdlg('Create new combined Marker?','Combine Markers', 'Yes', 'No','No');
        if strcmp(r,'Yes')

            output = inputdlg('Enter Marker Name','Edit Markers', [1 50],{'NewMarker'});
            newName = output{1};
              
            if ~isempty( find( strcmp(newName, names) == 1))
                warndlg('A Marker with this name already exists ...');
                return;
            end

            numMarkers = numel(names);

            for k=1:numMarkers
                % note structure passed to bw_writeNewMarkerFile is slightly different that       
                % that returned from readMarkerData including shift of trial numbering ...
                newMarkerData(k).ch_name = char(names(k)); 
                markerTimes = markerData{k};
                newMarkerData(k).trials = markerTimes(:,1) - 1;
                newMarkerData(k).latencies = markerTimes(:,2);
            end
            % add new marker - assume we are working with single trial data!

            % Markers should be in temporal order

            latencies = sort(latencies);
            newMarkerData(numMarkers+1).ch_name = newName; 
            newMarkerData(numMarkers+1).trials = zeros(size(latencies,1),1);
            newMarkerData(numMarkers+1).latencies = latencies;

            bw_writeNewMarkerFile(dsName, newMarkerData);   

            [names, markerData] = bw_readCTFMarkerFile(markerFileName);     
         
            set(Event_popup,'string',names);
            set(Event_popup2,'string',names);

        end

    end

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.1 0.2 0.15],'string','OK','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);
    
    function ok_callback(~,~)
        uiresume(gcf);
    end

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.5 0.1 0.2 0.15],'string','Cancel','backgroundcolor','white',...
        'callback',@cancel_callback);

    function cancel_callback(~,~)
        uiresume(gcf);
    end

    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
    
    
end
