function params =  bw_readPrefsFile(file)

    global BW_VERSION
    
    fprintf('Reading settings from %s...\n', file);
        
    % new - version check    
    t_params=load(file);
  
    if ~isfield(t_params,'version')      
        fprintf('Preferences saved for older version of BrainWave, updating ...\n');
        params = bw_setDefaultParameters;    
    else
        if t_params.version ~= BW_VERSION 
            fprintf('Preferences saved for version %.1f of BrainWave, updating ...\n', t_params.version);
            params = bw_setDefaultParameters; 
        else
            params = t_params;
        end
    end        
    
end