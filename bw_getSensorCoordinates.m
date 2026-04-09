function [coordinates, orientations] = bw_getSensorCoordinates(dsName, dewarCoordinates)

    if ~exist('dewarCoordinates','var')
        dewarCoordinates = 0;
    end

    coordinates = [];
    orientations = [];

    header = bw_CTFGetHeader(dsName);
     
    % look for grads or mags
    idx = find([header.channel.sensorType] == 5);

    if isempty(idx)
        idx = find([header.channel.sensorType] == 4);
    end

    if isempty(idx)
        fprintf('No sensor channels found...\n');
        return;
    end

    sensors = header.channel(idx);

    if dewarCoordinates == 0
        % create nsensors x 3 array
        coordinates = [[sensors.xpos]; [sensors.ypos]; [sensors.zpos]]';
        orientations = [[sensors.p1x]; [sensors.p1y]; [sensors.p1z]]';
    else
        coordinates = [[sensors.xpos_dewar]; [sensors.ypos_dewar]; [sensors.zpos_dewar]]';
        orientations = [[sensors.p1x_dewar]; [sensors.p1y_dewar]; [sensors.p1z_dewar]]';
    end


end