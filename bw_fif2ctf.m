%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
% function dsName = bw_fif2ctf(filename,  noTransform)
%
%   matlab routine to convert a FIFF file to CTF .ds format
%   assumes data is collected in raw format
% 
%   requires the mne-matlab toolbox to read FIFF files. 
%   https://github.com/mne-tools/mne-matlab
%
% 
%   input:   filename.fif:  FIF format MEG file
%            noTransform:   flag = TRUE to exclude conversion to head coordinates
% 
%   output:  name of CTF dataset (filename.ds )
%
%   
%   written by D. Cheyne, December, 2025
%
%   initial working version for both FieldLine and Elekta / MEGIN fif files.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function dsName = bw_fif2ctf(fifFile, noTransform)

    dsName = [];
    fids_dewar = [];
    fids_head = [];
    fifVersion = 'unknown';

    if ~exist('fiff_open')
        fprintf('Error: requires mne-matlab toolbox installed and in your Matlab path\n');
        fprintf('(Availabe at: https://github.com/mne-tools/mne-matlab)\n');
        return;
    end
        
    if ~exist(fifFile,'file')
        fprintf('Could not find the file %s\n',fifFile);
        return;
    end

    if ~exist('noTransform','var')
        noTransform = false;
    end

    % get header information 
    [fid, tree]  = fiff_open(fifFile);
    [info, ~] = fiff_read_meas_info(fid, tree);
    fclose(fid);

    types = [info.chs.coil_type];
    
    if ismember(8101,types)
        fifVersion = 'FieldLine_V3';
        fprintf('Detected sensor type 8101 - converting FieldLine V3 to CTF ...')
    end

    if ismember(3012,types) || ismember(3013,types) || ismember(3014,types) || ...
        ismember(3022,types) || ismember(3023,types) || ismember(3024,types)
        fifVersion = 'MEGIN';
        fprintf('Detected Elekta/MEGIN sensor types, converting to CTF  ...')
    end

    [~, runname, ~] = fileparts(fifFile);

    % build a res4 structure for .ds format

    res4 = [];
    res4.header = 'MEG42RS';
  
    res4.appName='';
    res4.dataOrigin='';
    res4.dataDescription='';
    res4.no_trials_avgd = 0;
  
    res4.data_date = date;
    res4.data_time = '';

    res4.no_channels = info.nchan;
    res4.sample_rate = info.sfreq;     

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % get device to head transform from header
    dev2head = info.dev_head_t.trans';
    
    % if dev2head is identity matrix we can assume there is no
    % co-registration for this data. Save in device coordinates. 

    I = eye(4);
    tolerance = 1e-10;
    if all(abs(dev2head - I) < tolerance, 'all')
        hasCoregistation = false;
    else
        hasCoregistation = true;
    end

        
    CTF2Head = [];
    % if enabled transform read FIF fiducials from header. 
    % *Note these are in FIF HEAD coordinates and cannot be used to 
    % transform the sensor geometry to CTF head coordinates
    if ~noTransform

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % get fiducials from FIF header
        % order seems to be 1,2 3 = LE, NA, RE
        hpi = info.dig(:,1:6);
    
        if ~isempty(hpi)
    
            NA = [hpi(2).r(1) hpi(2).r(2) hpi(2).r(3)];
            LE = [hpi(1).r(1) hpi(1).r(2) hpi(1).r(3)];
            RE = [hpi(3).r(1) hpi(3).r(2) hpi(3).r(3)];
            
            % Fiducials are in fif 'head' coordinates and must be converted
            % back to device / dewar coordinates! 
    
            NA_device = [NA 1] * inv(dev2head);
            LE_device = [LE 1] * inv(dev2head);
            RE_device = [RE 1] * inv(dev2head);
            
            % rotate to be +x towards nose, +y towards left ear
            NA_CTF = [NA_device(2) -NA_device(1) NA_device(3)];
            LE_CTF = [LE_device(2) -LE_device(1) LE_device(3)];
            RE_CTF = [RE_device(2) -RE_device(1) RE_device(3)];
    
            fids_dewar.na = NA_CTF * 100.0;
            fids_dewar.le = LE_CTF * 100.0;
            fids_dewar.re = RE_CTF * 100.0;
            CTF2Head = getCTFCoordinateTransform(fids_dewar.na, fids_dewar.le, fids_dewar.re);
        else
            % may have valid dev2head matrix but don't know the fiducials to
            % save in CTF coordinates...
            hasCoregistation = false;
            fprintf('No valid head digitization (fiducials) in fif header...\n')
            fprintf('Sensor geometry will be saved in device coordinates..\n')
       end
    else
        hasCoregistation = false;
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % extract sensor geometry

    % For FIF files the device coordinates appear to have + x 
    % towards right ear, +y towards nose
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    fprintf('Extracting channel information...\n');
    if hasCoregistation
        fprintf('Has valid co-registration = TRUE\n');
    else
        fprintf('Has valid co-registration = FALSE\n');
    end
    
    if strcmp(fifVersion,'FieldLine_V3')

        for k=1:info.nchan 
            chan = info.chs(:,k);
            res4.chanNames(k)=cellstr(chan.ch_name);
            loc = chan.loc;
            switch chan.coil_type
                case 8101   % FieldLine magnetometer
                    
                    coilNo = 1;  % no need to loop over coils for mags.                                   
                    res4.senres(k).sensorTypeIndex = 4;

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % get channel location and orientation in device coords
                    % info.locs table (for mags) contains one position 
                    % vector and three orientation vectors for 3 possible sense directions. 
                    % For FieldLine the z-orientation appears to always
                    % code the sense direction
                    %
                    pos0 = [loc(1) loc(2) loc(3)];      % pos0 = sensor geometry in DEVICE coordinates
                    ori0 = [loc(10) loc(11) loc(12)];  

                    % save device coordinates in the CoilTbl
                    res4.senres(k).pos0(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100;   % CoilTbl is +x forward and in cm
                    res4.senres(k).ori0(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];   
                    
                    % apply CTF head transformation if have fiducials
                    if hasCoregistation
                        posCTF = [pos0(2) -pos0(1) pos0(3)] * 100;
                        posHead = [posCTF 1] * CTF2Head;
                        pos = posHead(1:3);
                        rmat = CTF2Head(1:3,1:3);
                        oriCTF = [ori0(2) -ori0(1) ori0(3)] * rmat;

                        res4.senres(k).pos(1:3,coilNo) = pos; % HdCoilTbl is head coords
                        res4.senres(k).ori(1:3,coilNo) = -oriCTF;  
                    else
                        % else save HdCoilTbl in device coordinates
                        res4.senres(k).pos(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100; % HdCoilTbl is head coords in cm
                        res4.senres(k).ori(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];  
                    end                 

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % set sensor gain so that when scaled from Tesla to
                    % integers the LSB will be 1e-17 (0.01 femtoTesla)
                    %
                    res4.senres(k).properGain = 1e17;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;  

                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 1;        % from ctfCoilMap file
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 1;         % assumes magnetometer                    
                    res4.senres(k).numturns(1) = 1;      % n/a                    
                    res4.senres(k).area(1) = 0.04;      % value from mapFile
                    
                case 0   % FieldLine digital / stim channel
                    res4.senres(k).sensorTypeIndex = 11;     
                    % hdCoilTbl
                    res4.senres(k).pos0(:,1) = [0; 0; 0];
                    res4.senres(k).ori0(:,1) = [1; 0; 0];
                    res4.senres(k).pos(:,1) = [0; 0; 0];
                    res4.senres(k).ori(:,1) = [1; 0; 0];

                    res4.senres(k).properGain = 1;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;              % units are bits ?
                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 0;           
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 0;                            
                    res4.senres(k).numturns(1) = 0;                    
                    res4.senres(k).area(1) = 0.0;    

                otherwise
                 
                    % unknown channel type - write as digital for now ....
                    % need index for ADC channels
                    res4.senres(k).sensorTypeIndex = 11;     
                    % hdCoilTbl
                    res4.senres(k).pos0(:,1) = [0; 0; 0];
                    res4.senres(k).ori0(:,1) = [1; 0; 0];
                    res4.senres(k).pos(:,1) = [0; 0; 0];
                    res4.senres(k).ori(:,1) = [1; 0; 0];

                    res4.senres(k).properGain = 1;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;              
                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 0;           
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 0;                            
                    res4.senres(k).numturns(1) = 0;                    
                    res4.senres(k).area(1) = 0.0;    
            end

        end

    elseif strcmp(fifVersion,'MEGIN')

        for k=1:info.nchan 
            chan = info.chs(:,k);
            res4.chanNames(k) = cellstr(chan.ch_name);
            loc = chan.loc;
            switch chan.coil_type
                case {3012, 3013, 3014}   % Elekta / MEGIN planar grads
                     
                    % although planar grad can code in CTF as axial grad since orientation vectors are known  
                    res4.senres(k).sensorTypeIndex = 5;     
                    z_offset = 0.0003;
                    gradOffset = 0.0168 / 2.0;
             
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % get channel location and orientation in device coords
                    % For FIF orientation vectors appear to be 
                    % defined such that z orientation loc(10:12)
                    % always points in the sense direction.              
                    pos_ctr = [loc(1) loc(2) loc(3)];   
                    oriZ = [loc(10) loc(11) loc(12)];  
 
                    % ** note MEGIN sensors have an z_offset of 0.0003 m
                    % in the z direction that has to be added 
                    pos_ctr = pos_ctr + (oriZ * z_offset);

                    % for planar grads the coil locations lie along the
                    % x-axis a distance of 1/2 the baseline (1.68 cm / 2)
                    % from the centre (pos_ctr).
                    % first coil is in +x direction and second coil is in -x direction
                    % orientation for first coil is in the +z direction.
                    % and for second coil in the -z direction
                    grad_axis = [loc(4) loc(5) loc(6)];   % x-orientation

                    for coilNo = 1:2 
                        if coilNo == 1
                            pos0 = pos_ctr + (grad_axis * gradOffset); 
                            ori0 = oriZ;
                        else
                            pos0 = pos_ctr - (grad_axis * gradOffset);
                            ori0 = -oriZ; 
                        end            
                    
                        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
                        % Rotate 90 deg (x = y, y = -x) to be consistent with
                        % CTF (+x towards nose) and scale to cm   
                        res4.senres(k).pos0(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100;   % CoilTbl is dewar / device in cm
                        % Negative sign is because p-vectors for CTF point 
                        % away from gradiometer (into the head).  
                        res4.senres(k).ori0(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];         
                     
                        % apply CTF head transformation if have fiducials
                        if hasCoregistation
                            posCTF = [pos0(2) -pos0(1) pos0(3)] * 100;
                            posHead = [posCTF 1] * CTF2Head;
                            pos = posHead(1:3);
                            rmat = CTF2Head(1:3,1:3);
                            oriCTF = [ori0(2) -ori0(1) ori0(3)] * rmat;
    
                            res4.senres(k).pos(1:3,coilNo) = pos;   % HdCoilTbl is head coords in cm
                            res4.senres(k).ori(1:3,coilNo) = -oriCTF;  
                        else
                            % else save HdCoilTbl in device coordinates - e.g.,
                            % no HPI localization was done ...
                            res4.senres(k).pos(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100; % HdCoilTbl is head coords in cm
                            res4.senres(k).ori(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];  
                        end  
                    end

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % set sensor gain so that when scaled from Tesla to
                    % integers the LSB will be 1e-17 (0.01 femtoTesla)
                    %
                    res4.senres(k).properGain = 1e17;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;  

                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 1;        
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 2;                           
                    res4.senres(k).numturns(1) = 1;                            
                    res4.senres(k).numturns(2) = 1;                            
                    res4.senres(k).area(1) = 2.59;    
                    res4.senres(k).area(2) = 2.59;    

                case {3022, 3023, 3024}   % Elekta / MEGIN magnetometers
                    res4.senres(k).sensorTypeIndex = 4;                
                    coilNo = 1;                                   
                    z_offset = 0.0003;

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % get channel location and orientation in device coords
                    % For FIF orientation vectors appear to be 
                    % defined such that z orientation loc(10:12)
                    % always points in the sense direction.    

                    pos0 = [loc(1) loc(2) loc(3)];   
                    ori0 = [loc(10) loc(11) loc(12)];  

                    % ** note MEGIN sensors have an z_offset of 0.3 mm
                    % in the Z direction that has to be added 
                    pos0 = pos0 + (ori0 * z_offset);
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
                    % Rotate 90 deg (x = y, y = -x) to be consistent with
                    % CTF (+x towards nose) and scale to cm                    
                    res4.senres(k).pos0(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100;   % CoilTbl is dewar / device in cm
                    % Negative sign is because p-vectors for CTF point 
                    % away from gradiometer (into the head).  
                    res4.senres(k).ori0(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];         
                 
                    % apply CTF head transformation if have fiducials
                    if hasCoregistation
                        posCTF = [pos0(2) -pos0(1) pos0(3)] * 100;
                        posHead = [posCTF 1] * CTF2Head;
                        pos = posHead(1:3);
                        rmat = CTF2Head(1:3,1:3);
                        oriCTF = [ori0(2) -ori0(1) ori0(3)] * rmat;

                        res4.senres(k).pos(1:3,coilNo) = pos;   % HdCoilTbl is head coords in cm
                        res4.senres(k).ori(1:3,coilNo) = -oriCTF;  
                    else
                        % else save HdCoilTbl in device coordinates 
                        res4.senres(k).pos(1:3,coilNo) = [pos0(2) -pos0(1) pos0(3)] * 100; 
                        res4.senres(k).ori(1:3,coilNo) = -[ori0(2) -ori0(1) ori0(3)];  
                    end  

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % set sensor gain so that when scaled from Tesla to
                    % integers the LSB will be 1e-17 (0.01 femtoTesla)
                    %
                    res4.senres(k).properGain = 1e17;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;  

                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 1;        
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 1;                           
                    res4.senres(k).numturns(1) = 1;                        
                    res4.senres(k).area(1) = 4.41;    

                otherwise
                 
                    % unknown channel type - write as digital for now ....
                    % need index for ADC channels
                    res4.senres(k).sensorTypeIndex = 11;     
                    % hdCoilTbl
                    res4.senres(k).pos0(:,1) = [0; 0; 0];
                    res4.senres(k).ori0(:,1) = [1; 0; 0];
                    res4.senres(k).pos(:,1) = [0; 0; 0];
                    res4.senres(k).ori(:,1) = [1; 0; 0];

                    res4.senres(k).properGain = 1;
                    res4.senres(k).qGain = 1;
                    res4.senres(k).ioGain = 1;              
                    res4.senres(k).ioOffset = 0;
                    res4.senres(k).originalRunNum = 0;
                    res4.senres(k).coilShape = 0;           
                    res4.senres(k).grad_order_no = 0;
                    res4.senres(k).numCoils = 0;                            
                    res4.senres(k).numturns(1) = 0;                    
                    res4.senres(k).area(1) = 0.0;                    
            end
        end

    else
        fprintf('Unsupported FIFF version ..,.\n');
        return;
    end

  
    % ++++ other (unused) res4 stuff...
    res4.numcoef = 0;           % no coeffs
    
    % meg41TriggerData part of new_general_setup_rec_ext   10 bytes total
    res4.primaryTrigger = 0;
    res4.secondaryTrigger = 0;
    res4.triggerPolarityMask = 0; 
    
    % end of meg41TriggerData part of new_general_setup_rec_ext
    res4.trigger_mode = 0;   
    res4.accept_reject_Flag = 0;  
    res4.run_time_display = 0;
    
    res4.zero_Head_Flag = 0;      
    res4.artifact_mode = 0;       
    %  end of new_general_setup_rec_ext part of meg41GeneralResRec
    % meg4FileSetup part of meg41GeneralResRec
    res4.nf_run_name = runname;
    res4.nf_run_title = runname; 
    res4.nf_instruments= '';
    
    res4.nf_subject_id= '';
    res4.nf_operator= 'none';
    res4.nf_sensorFileName= '';
    
    res4.run_description = 'Dataset created by bw_fif2ctf';
    res4.size=length(res4.run_description);
    res4.nf_collect_descriptor= res4.run_description;
    %  end of meg4FileSetup part of meg41GeneralResRec
    
    % filter descriptions -- needed? 
    res4.fClass = 1;
    res4.fNumParams = 0;
    res4.lowPass = info.lowpass; % assume always is lowpass...
    res4.num_filters = 1;       
    res4.highPass = info.highpass;   
    if res4.highPass ~= 0.0
        res4.num_filters = 2;       
    end
         
    res4.no_trials_done = 0;    
    res4.no_trials_display = 0; 
    res4.save_trials = 0;  

    % end of filter descriptions

    % ++++++++++++++++ get data ++++++++++++++++
    % assume is always raw data that can be read in fast mode
    if strcmp(fifVersion,'FieldLine_V3')

        raw = fiff_setup_read_raw(fifFile,0);
        [data, ~] = fiff_read_raw_segment(raw);     
        
        samplesRead = size(data,2);
        if samplesRead == 0
            fprintf('Failed reading data segment');
            return;
        end

        % can now complete rest of header ...
        res4.no_samples = samplesRead;
        res4.no_trials = 1;     
        res4.preTrigPts = 0;     
        trialDuration = res4.no_samples * (1.0 / res4.sample_rate);
        res4.epoch_time = trialDuration * res4.no_trials;
        
    elseif strcmp(fifVersion,'MEGIN')
        % for now assume MEGIN data will be raw data
        % * need to check for MaxShield ?
        raw = fiff_setup_read_raw(fifFile,0);
        [data, ~] = fiff_read_raw_segment(raw);     

        samplesRead = size(data,2);
        if samplesRead == 0
            fprintf('Failed reading data segment');
            return;
        end

        % can now complete rest of header ...
        res4.no_samples = samplesRead;
        res4.no_trials = 1;  
        res4.preTrigPts = 0;     
        trialDuration = res4.no_samples * (1.0 / res4.sample_rate);
        res4.epoch_time = trialDuration * res4.no_trials;
                
    else
        fprintf('Unsupported FIFF version ..,.\n');
        return;
    end

    % ++++++++++++++++ write .ds format file ++++++++++++++++

    % create the .ds folder and write .res4 file.

    dsName = strrep(fifFile,'.fif','.ds');       
    if ~exist(dsName,'dir')
        fprintf('Creating .ds folder %s\n', dsName);
        mkdir(dsName);
        fileattrib(dsName,'+w','ug');
    end

    [~, basename, ~] = fileparts(dsName);
    res4File = strcat(dsName, filesep, basename,'.res4');   

    fprintf('writing CTF res4 header...\n');

    err = writeRes4(res4File,res4);
    if (err == -1)
        fprintf('writeRes4 returned error\n');
        dsName = [];
        return;
    end

    % open .meg4 file and write data ....

    [~,NAME,~] = fileparts(dsName);
    fname = strcat(NAME,'.meg4');
    meg4File = fullfile(dsName,fname);

    fid2 = fopen(meg4File,'wb','ieee-be');
    if (fid2 == -1)
        fprintf('Could not open %s for writing...\n', meg4File);
        dsName = [];
        return;
    end

    head = sprintf('MEG41CP');
    fwrite(fid2,[head(1:7),char(0)],'uint8');

    fprintf('writing %d channels of data... \n',res4.no_channels);
    % scale data (in Tesla) to integers 
    for k=1:res4.no_channels
        y = data(k,:);
        gain = res4.senres(k).properGain;
        data(k,:) =round( y * gain );
    end
    fwrite(fid2, data', 'int32');

    fclose(fid2);
     
    clear data;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % write a CTF .hc file
    % 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(CTF2Head)
        % create a CTF head coil (*.hc) file
        % only critical values are the measured fiducials
        % 
        % for non-CTF data it is not clear what standard head position 
        % should be so just set it to the measured fiducials   
        fid_standard = fids_dewar;

        % .hc also saves the fiducials transformed to head coordinates
        na = [fids_dewar.na 1] * CTF2Head;
        le = [fids_dewar.le 1] * CTF2Head;
        re = [fids_dewar.re 1] * CTF2Head;
        fids_head.na = na(1:3);
        fids_head.le = le(1:3);
        fids_head.re = re(1:3);
        writeHeadCoilFile(dsName, fid_standard, fids_head, fids_dewar);
    end    

end

function err = writeRes4(res4File,res4)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  Write a CTF .res4 file.  Use ieee-be (big endian) format
    %  Character-string output is done using function writeCTFstring which
    %  checks that strings are the correct length for the .res4 file format.
    %
    %  Modified by M. Woodbury from CTF version for Yokogawa datasets
    %   
    %   Nov 2025 - modified from yokagawa_writeRes4.m  
    %   D. Cheyne, November, 2025
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    MAX_COILS = 8;

    fid_res4=fopen(res4File,'w','b');
    if fid_res4<0
      fprintf('writeRes4: Could not open file %s\n',res4File);
      err = -1;
      return
    end
    
    fwrite(fid_res4,[res4.header(1:7),char(0)],'uint8');   % 8-byte header
    
    %  meg41GeneralResRec
    res4.appName=writeCTFstring(res4.appName,-256,fid_res4);
    res4.dataOrigin=writeCTFstring(res4.dataOrigin,-256,fid_res4);
    res4.dataDescription=writeCTFstring(res4.dataDescription,-256,fid_res4);
    fwrite(fid_res4,res4.no_trials_avgd,'int16');
    res4.data_time=writeCTFstring(res4.data_time,255,fid_res4);
    res4.data_date=writeCTFstring(res4.data_date,255,fid_res4);
    
    % new_general_setup_rec_ext part of meg41GeneralResRec
    
    fwrite(fid_res4,res4.no_samples,'int32');        % 4
    fwrite(fid_res4,[res4.no_channels 0],'int16');   % 2*2
    fwrite(fid_res4,res4.sample_rate,'double');      % 8
    fwrite(fid_res4,res4.epoch_time,'double');       % 8
    fwrite(fid_res4,[res4.no_trials 0],'int16');     % 2*2
    fwrite(fid_res4,res4.preTrigPts,'int32');        % 4
    fwrite(fid_res4,res4.no_trials_done,'int16');    % 2
    fwrite(fid_res4,res4.no_trials_display,'int16'); % 2
    fwrite(fid_res4,res4.save_trials,'int32');       % 4 CTFBoolean
    
    % meg41TriggerData part of new_general_setup_rec_ext   10 bytes total
    fwrite(fid_res4,res4.primaryTrigger,'uchar');      % 1
    fwrite(fid_res4,res4.secondaryTrigger,'uchar');    % 1
    fwrite(fid_res4,res4.triggerPolarityMask,'uchar'); % 1
    fwrite(fid_res4,[0 0],'uint8');                    % 2 bytes
    % end of meg41TriggerData part of new_general_setup_rec_ext
    
    fwrite(fid_res4,res4.trigger_mode,'int16');    % 2
    fwrite(fid_res4,0,'uchar');                    % 1
    fwrite(fid_res4,res4.accept_reject_Flag,'int32');  % 4 CTFBoolean
    fwrite(fid_res4,[res4.run_time_display 0],'int16');% 2*2
    
    fwrite(fid_res4,res4.zero_Head_Flag,'int32');      % 4 CTFBoolean
    fwrite(fid_res4,res4.artifact_mode,'int32');       % 4 CTFBoolean
    %  end of new_general_setup_rec_ext part of meg41GeneralResRec
    
    fwrite(fid_res4,[0 0],'int32');                   % 8 bytes (makes up rest of new_general_setup_rec_ext size
    
    % meg4FileSetup part of meg41GeneralResRec
    res4.nf_run_name=writeCTFstring(res4.nf_run_name,32,fid_res4);
    res4.nf_run_title=writeCTFstring(res4.nf_run_title,-256,fid_res4);
    res4.nf_instruments=writeCTFstring(res4.nf_instruments,32,fid_res4);
    res4.nf_collect_descriptor=writeCTFstring(res4.nf_collect_descriptor,32,fid_res4);
    res4.nf_subject_id=writeCTFstring(res4.nf_subject_id,-32,fid_res4);
    res4.nf_operator=writeCTFstring(res4.nf_operator,32,fid_res4);
    res4.nf_sensorFileName=writeCTFstring(res4.nf_sensorFileName,60,fid_res4);
    res4.size=length(res4.run_description);      % Run_description may have been changed.
    fwrite(fid_res4,res4.size,'int32');    
    
    %  end of meg4FileSetup part of meg41GeneralResRec
    fwrite(fid_res4,[0 0],'int16');                    % 4 bytes padding
    res4.run_description=writeCTFstring(res4.run_description,res4.size,fid_res4);
    
    %  filter descriptions
    
    fwrite(fid_res4,res4.num_filters,'int16');      %2
    if ~(res4.highPass == 0)
      fwrite(fid_res4,res4.highPass,'double');      %8
      fwrite(fid_res4,res4.fClass,'int32');         %4
      fType = 2; % HIGHPASS
      fwrite(fid_res4,fType,'int32');               %4
      fwrite(fid_res4,res4.fNumParams,'int16');     %2
    end
    fwrite(fid_res4,res4.lowPass,'double');         %8
    fwrite(fid_res4,res4.fClass,'int32');           %4
    fType = 1; % LOWPASS
    fwrite(fid_res4,fType,'int32');                 %4
    fwrite(fid_res4,res4.fNumParams,'int16');       %2
    
    
    %  Write channel names.   Must have size(res4.chanNames)=[nChan 32] 
    for kchan=1:res4.no_channels
      s = char(res4.chanNames(kchan));
      res4.chanNamesStr(kchan,1:32)=writeCTFstring(s,32,fid_res4);
    end
    
    %  Write sensor resource table
    for kchan=1:res4.no_channels
      fwrite(fid_res4,res4.senres(kchan).sensorTypeIndex,'int16');
      fwrite(fid_res4,res4.senres(kchan).originalRunNum,'int16');
      fwrite(fid_res4,res4.senres(kchan).coilShape,'int32');
      fwrite(fid_res4,res4.senres(kchan).properGain,'double');
      fwrite(fid_res4,res4.senres(kchan).qGain,'double');
      fwrite(fid_res4,res4.senres(kchan).ioGain,'double');
      fwrite(fid_res4,res4.senres(kchan).ioOffset,'double');
      fwrite(fid_res4,res4.senres(kchan).numCoils,'int16');
      numCoils=res4.senres(kchan).numCoils;
      fwrite(fid_res4,res4.senres(kchan).grad_order_no,'int16');
      fwrite(fid_res4,0,'int32');  % Padding to 8-byte boundary
      
      % coilTbl
      for qx=1:numCoils
        fwrite(fid_res4,[res4.senres(kchan).pos0(:,qx)' 0],'double');
        fwrite(fid_res4,[res4.senres(kchan).ori0(:,qx)' 0],'double');
        fwrite(fid_res4,[res4.senres(kchan).numturns(qx) 0 0 0],'int16');
        fwrite(fid_res4,res4.senres(kchan).area(qx),'double');
      end
      if numCoils<MAX_COILS
        fwrite(fid_res4,zeros(10*(MAX_COILS-numCoils),1),'double');  
      end
      
      %HdcoilTbl
      for qx=1:numCoils
        fwrite(fid_res4,[res4.senres(kchan).pos(:,qx)' 0],'double');
        fwrite(fid_res4,[res4.senres(kchan).ori(:,qx)' 0],'double');
        fwrite(fid_res4,[res4.senres(kchan).numturns(qx) 0 0 0],'int16');
        fwrite(fid_res4,res4.senres(kchan).area(qx),'double');
      end
      if numCoils<MAX_COILS
        fwrite(fid_res4,zeros(10*(MAX_COILS-numCoils),1),'double');  
      end
    end
    %  End writing sensor resource table
    
    %  Write the table of balance coefficients.
    if res4.numcoef<=0
      fwrite(fid_res4,res4.numcoef,'int16');  % Number of coefficient records
    elseif res4.numcoef>0
      scrx_out=[];
      for kx=1:res4.numcoef
        sName=strtok(char(res4.scrr(kx).sensorName),['- ',char(0)]);
        if ~isempty(strmatch(sName,res4.chanNamesStr))
          scrx_out=[scrx_out kx];
        end
      end
      %  Remove the extra coefficient records
      res4.scrr=res4.scrr(scrx_out);
      res4.numcoef=size(res4.scrr,2);
      fwrite(fid_res4,res4.numcoef,'int16');  % Number of coefficient records
      %  Convert res4.scrr to double before writing to output file.  In MATLAB 5.3.1, 
      %  when the 'ieee-be' option is applied, fwrite cannot write anything except 
      %  doubles and character strings, even if fwrite does allow you to specify short
      %  integer formats in the output file.
      for nx=1:res4.numcoef
        fwrite(fid_res4,double(res4.scrr(nx).sensorName),'uint8');
        fwrite(fid_res4,[double(res4.scrr(nx).coefType) 0 0 0 0],'uint8');
        fwrite(fid_res4,double(res4.scrr(nx).numcoefs),'int16');
        fwrite(fid_res4,double(res4.scrr(nx).sensor),'uint8');
        fwrite(fid_res4,res4.scrr(nx).coefs,'double');
      end
    end
    status = fclose(fid_res4);
    if status == -1
      err = status;
      return;
    end
          
    err = 0;

end


function strng=writeCTFstring(instrng,strlength,fid)

    %  Writes a character string to output unit fid.  Append nulls to get the correct length.
    %  instrng : Character string.  size(instrng)=[nLine nPerLine].  strng is reformulated as a
    %            long string of size [1 nChar].  Multiple lines are allowed so the user can
    %            easily append text.  If necessary, characters are removed from
    %            instrng(1:nLine-1,:) so all of strng(nLine,:) can be accomodated.
    %    strlength: Number of characters to write.  strlength<0 means remove leading characters.
    %        If abs(strlength)>length(strng) pad with nulls (char(0))
    %        If 0<strlength<length(strng), truncate strng and terminate with a null.
    %        If -length(string)<strlength<0, remove leading characters and terminate with a null.

    %  Form a single long string
    nLine=size(instrng,1);
    if nLine > 0
      strng=deblank(instrng(1,:));
    else
      strng = instrng;
    end
    
    if nLine>1
      %  Concatenate lines 1:nLine-1
      for k=2:nLine-1
        if length(strng)>0
          if ~strcmp(strng(length(strng)),'.') & ~strcmp(strng(length(strng)),',')
            strng=[strng '.'];   % Force a period at the end of the string.
          end
        end
        strng=[strng '  ' deblank(instrng(k,:))];
      end
      
      if length(strng)>0
        if ~strcmp(strng(length(strng)),'.')  % Force a period at the end of the string.
          strng=[strng '.'];
        end
      end
      %  Add all of the last line.
      nChar=length(strng);
      nLast=length(deblank(instrng(nLine,:)));
      strng=[strng(1:min(nChar,abs(strlength)-nLast-4)) '  ' deblank(instrng(nLine,:))];
    end
    
    if length(strng)<abs(strlength)
      strng=[strng char(zeros(1,abs(strlength)-length(strng)))];
    elseif length(strng)>strlength & strlength>0
      strng=[strng(1:strlength-1) char(0)];
    elseif length(strng)==strlength & strlength>0
      strng=strng;
    else
       strng=[strng(nLast+[strlength+2:0]) char(0)];
    end
    
    fwrite(fid,strng,'char');
end



function writeHeadCoilFile(dsName, fid_pts_standard, fid_pts_head, fid_pts_dewar)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %   stand-alone version of bw_writeHeadCoilFile for converting FIFF files..
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    na_standard = fid_pts_standard.na;      % 'default' head position
    le_standard = fid_pts_standard.le;
    re_standard = fid_pts_standard.re;
    
    na_head = fid_pts_head.na;              % fiducials in head coordinates
    le_head = fid_pts_head.le;
    re_head = fid_pts_head.re;
    
    na_dewar = fid_pts_dewar.na;            % fiducials in device coordinates
    le_dewar = fid_pts_dewar.le;
    re_dewar = fid_pts_dewar.re;   
    
    [~, name, ~] = fileparts(dsName);
    hcname = sprintf('%s.hc',name);
    filename = fullfile(dsName,hcname);
    
    fp = fopen(filename,'w');
    if (fp == -1)
        fprintf('failed to open file %s',filename);
        return;
    end
    
    fprintf('Writing head coil file to %s ...\n', dsName)
    
    % default head position
    fprintf(fp, 'standard nasion coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', na_standard(1));
    fprintf(fp, '\ty = %.5f\n', na_standard(2));
    fprintf(fp, '\tz = %.5f\n', na_standard(3));	
    fprintf(fp, 'standard left ear coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', le_standard(1));
    fprintf(fp, '\ty = %.5f\n', le_standard(2));
    fprintf(fp, '\tz = %.5f\n', le_standard(3));	
    fprintf(fp, 'standard right ear coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', re_standard(1));
    fprintf(fp, '\ty = %.5f\n', re_standard(2));
    fprintf(fp, '\tz = %.5f\n', re_standard(3));
    fprintf(fp, 'standard inion coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = 0\n');
    fprintf(fp, '\ty = 0\n');
    fprintf(fp, '\tz = 0\n');	
    fprintf(fp, 'standard Cz coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = 0\n');
    fprintf(fp, '\ty = 0\n');
    fprintf(fp, '\tz = 0\n');	
    
    fprintf(fp, 'measured nasion coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', na_dewar(1));
    fprintf(fp, '\ty = %.5f\n', na_dewar(2));
    fprintf(fp, '\tz = %.5f\n', na_dewar(3));	
    fprintf(fp, 'measured left ear coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', le_dewar(1));
    fprintf(fp, '\ty = %.5f\n', le_dewar(2));
    fprintf(fp, '\tz = %.5f\n', le_dewar(3));
    fprintf(fp, 'measured right ear coil position relative to dewar (cm):\n');
    fprintf(fp, '\tx = %.5f\n', re_dewar(1));
    fprintf(fp, '\ty = %.5f\n', re_dewar(2));
    fprintf(fp, '\tz = %.5f\n', re_dewar(3));
    fprintf(fp, 'measured inion coil position relative to dewar (cm):\n');  
    fprintf(fp, '\tx = 0\n');
    fprintf(fp, '\ty = 0\n');
    fprintf(fp, '\tz = 0\n');	
    fprintf(fp, 'measured Cz coil position relative to dewar (cm):\n');		
    fprintf(fp, '\tx = 0\n');
    fprintf(fp, '\ty = 0\n');
    fprintf(fp, '\tz = 0\n');	
    
    fprintf(fp, 'measured nasion coil position relative to head (cm):\n');
    fprintf(fp, '\tx = %.5f\n', na_head(1));
    fprintf(fp, '\ty = %.5f\n', na_head(2));
    fprintf(fp, '\tz = %.5f\n', na_head(3));
    fprintf(fp, 'measured left ear coil position relative to head (cm):\n');
    fprintf(fp, '\tx = %.5f\n', le_head(1));
    fprintf(fp, '\ty = %.5f\n', le_head(2));
    fprintf(fp, '\tz = %.5f\n', le_head(3));
    fprintf(fp, 'measured3 right ear coil position relative to head (cm):\n');
    fprintf(fp, '\tx = %.5f\n', re_head(1));
    fprintf(fp, '\ty = %.5f\n', re_head(2));
    fprintf(fp, '\tz = %.5f\n', re_head(3));
    fprintf(fp, 'measured3 inion coil position relative to head (cm):\n'); 
    fprintf(fp, '\tx = 0.0\n');
    fprintf(fp, '\ty = 0.0\n');
    fprintf(fp, '\tz = 0.0\n');
    fprintf(fp, 'measured3 Cz coil position relative to head (cm):\n');
    fprintf(fp, '\tx = 0.0\n');
    fprintf(fp, '\ty = 0.0\n');
    fprintf(fp, '\tz = 0.0\n');
    
    fclose(fp);

end

function M = getCTFCoordinateTransform(nasion_pos, left_preauricular_pos, right_preauricular_pos, scaleFactor  )

    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % create a transformation matrix to CTF coordinates using fidiucials 
    % defined in other coordinates (e.g., dewar or device coordinates).
    % Right-handed coordinate system where origin is the midpoint between 
    % the left and right ear, x-axis from origin towards nasion and 
    % the y-axis towards left ear, rotated to be orthogonal to the x-axis.
    % scaleFactor = 1 means if passed fidicial locations are in cm, the
    % transformed coordinates will be in cm.
    % A scale factor can be passed to include scaling to different units
    % (e.g., from CTF coordinates to MRI voxels in mm) 
    % D. Cheyne Dec, 2025 - adapted from BrainWave bw_getAffineVox2CTF.m
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~exist('scaleFactor','var')
        scaleFactor = 1;
    end
    
    % build CTF coordinate system
    % origin is midpoint between ears
    origin = (left_preauricular_pos + right_preauricular_pos) / 2.0;
    
    % x axis is vector from this origin to Nasion
    x_axis = nasion_pos - origin; 
    x_axis=x_axis/norm(x_axis);
    
    % y axis is origin to left ear vector
    y_axis= left_preauricular_pos - origin;
    y_axis=y_axis/norm(y_axis);
    
    % This y-axis is not necessarely perpendicular to the x-axis, this corrects
    z_axis=cross(x_axis,y_axis);    
    % Note: z_axis will not be unit vector if x and y are not orthogonal!
    z_axis=z_axis/norm(z_axis);    
    
    y_axis=cross(z_axis,x_axis);
    y_axis=y_axis/norm(y_axis);
    
    % now build 4 x 4 affine transformation matrix
    
    % rotation matrix is constructed from the principal axes unit vectors
    % note transpose for correct direction of rotation 
    rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';
    
    % optional scaling 
    smat = diag([scaleFactor scaleFactor scaleFactor 1]);
    
    % translation - subtract the origin
    tmat = diag([1 1 1 1]);
    tmat(4,:) = [-origin, 1];
    
    % affine transformation is concatenation of the three transformations 
    % Order of operations is important. Rotation after translation to new origin.
    % Since origin is in fiducial units we must translate before any scaling.
    M = tmat * smat * rmat;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
