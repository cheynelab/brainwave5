
function player = playADC(dsName)

    player  = [];
    audio_data = [];
    audio_Fs = [];
    cursorHandlesAudio = [];

    startTime = [];
    endTime = [];

    if ~exist(dsName,'file')
        fprintf('Cannot find dataset %s. Make sure it is in the current path...\n', dsName);
        return;
    end
             
    fh_plot = figure('Position', [500 500 800 400], ...
        'menubar','none','numbertitle','off','Name','Audio Player');       
    
    audio_data = [];

    fprintf('loading audio data ...\n');
    header = readCTFHeader(dsName);
    badChannelMask = zeros(header.numChannels,1);
    channelIndex = bw_channelSelector(header,317,badChannelMask);

    if isempty(channelIndex)
        return;
    end

    audio_Fs = header.sampleRate;

    % if coil file is truncated have to adjust number of samples for
    % audio data
    startSample = 0; 
    startTime = header.epochMinTime;
    endTime = header.epochMaxTime;
    

    n_audioSamples = header.numSamples;
    audio_data = readCTFData(dsName, startSample,n_audioSamples,0, channelIndex);          % read data segment from .ds - all channels
        
    dwel = 1.0 / audio_Fs;    
    tVec = startTime: dwel: endTime;
    tVec = tVec(1:length(audio_data));  % adjust for rounding...

       
    startSample = 1;
    latency = 0.0;

    plot(tVec, audio_data,'black');
              
    % xlim([minRange maxRange]);
    ylims = ylim;
    mx = max(abs(ylims));
    ylim([-mx mx]);
    ylim('manual');

    title('Audio Signal');
    xlabel('Time (s)');
    ylabel('Amplitude');
    
    h = [latency latency];
    v = ylim;        
    cursorHandlesAudio = line(h,v, 'color', 'red');   

                           
    % scale ADC channel to 75% full dynamic range. 
    
    mn = mean(audio_data,1);        % remove any offset
    audio_data = audio_data - mn;
    mx = max(abs(audio_data));
    
    audio_data = (audio_data ./ mx) * 0.75;
    
    player = audioplayer(audio_data, audio_Fs);
    
    % play(player, [6000, length(audio_data)]);      

end