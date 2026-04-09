function [names, positions, orientations] = bw_getSensorPositions(dsName, deviceCoordinates)
    
    
    if exist('deviceCoordinates','var')
        useDeviceCoords = deviceCoordinates;
    else
        useDeviceCoords = 0;
    end
   
    header = bw_CTFGetHeader(dsName);

    chanTypes = [header.channel.sensorType];
    sensorChans = find(ismember(chanTypes,[4 5]));  
    channels = header.channel(sensorChans);
    names = {channels.name};

    % return tables

    if useDeviceCoords
        positions = [[channels.xpos_dewar]' [channels.ypos_dewar]' [channels.zpos_dewar]'];
        orientations = [[channels.p1x_dewar]' [channels.p1y_dewar]' [channels.p1z_dewar]'];
    else
        positions = [[channels.xpos]' [channels.ypos]' [channels.zpos]'];
        orientations = [[channels.p1x]' [channels.p1y]' [channels.p1z]'];
    end


 
end