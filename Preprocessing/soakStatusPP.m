function sample_data = soakStatusPP( sample_data, qcLevel, auto )
%binCTDpressPP( sample_data, auto)
%
% Checks surface depth at which pump
% turned on and depth after soak times set in soakStatusPP.txt
% these can be used later to QC for sufficient surface soak
%
% Inputs:
%   sample_data - cell array of data sets, ideally with pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
%   From soakStatusPP:
%           SoakDelay1:  Minimum Soak Time (default 1min)
%           SoakDelay2:  Optimal Soak Time (default 2min)
%
% Outputs:
%   sample_data - the same data sets, soak_status added.
%   new variable added to sample_data called SOAKSTATUS
%       values:
%           -1:  No Soak Status determined (usually elapsed time missing)
%            0:  Pump Off and/or Minimum Soak Interval has not passed 
%                    - data from sensors supplied by pump
%            1:  Pump On and first Minimum Soak Interval has passed - data
%                       from sensors are probably OK
%            2:  Pump On and Optimal Soak Interval has passed - data from
%                       all sensors assumed to be good.
%
% Author:       Charles James (charles.james@sa.gov.au)
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% read options from parameter file  Minimum Soak Delay: SoakDelay1 (sec.)
%                                   Optimal Soak Delay: SoakDelay2 (sec.)
PressFile = ['Preprocessing' filesep 'soakStatusPP.txt'];
tempMinSoak = str2double(readProperty('tempMinSoak', PressFile));
tempOptSoak = str2double(readProperty('tempOptSoak', PressFile));
cndMinSoak  = str2double(readProperty('cndMinSoak', PressFile));
cndOptSoak  = str2double(readProperty('cndOptSoak', PressFile));
oxMinSoak   = str2double(readProperty('oxMinSoak', PressFile));
oxOptSoak   = str2double(readProperty('oxOptSoak', PressFile));

% loop on every data sets
for k = 1:length(sample_data)
    use_pump = false;
    curSam = sample_data{k};
    % get pressure for soak times and binning
    presIdx     = getVar(curSam.variables, 'PRES');
    presRelIdx  = getVar(curSam.variables, 'PRES_REL');
    
    if presIdx == 0 && presRelIdx == 0
        continue;
    elseif presRelIdx ~= 0
        press = curSam.variables{presRelIdx}.data;
    else
        press = curSam.variables{presIdx}.data;
    end
    % need pressure to continue
    if isempty(press);continue;end
    
    % remove on deck pressure
    press = press - min(press);
    iin_water = find(press > 0.1, 1, 'first'); % finds the first index where the CTD is below the surface
    
    % need instrument pump delay, minimum conductivity frequency for pump
    % delay countdown to commence, conductivity frequency and total elapsed 
    % time in order to calculate when pump turned on.
    instHeader = curSam.meta.instHeader;
    % new pumpDelay and minCondFreq header data created in modified SBE19Parse
    if isfield(instHeader, 'pumpDelay');
        pumpDelay = instHeader.pumpDelay;
        use_pump = true;
        if isfield(instHeader, 'minCondFreq')
            minCondFreq = instHeader.minCondFreq;
        else
            use_pump = false;
        end
    end
    
    % elapsed time variable created in SBE19Parse
    iETime = getVar(curSam.variables, 'ETIME');
    if iETime ~= 0;
        elapsed_time = curSam.variables{iETime}.data;
    else
        elapsed_time = [];
    end
    
    if use_pump
        % Conductivity Frequency variable created in readSBE19cnv
        iFreq = getVar(curSam.variables, 'CNDC_FREQ');
        if (iFreq ~= 0) && ~isempty(elapsed_time)
            Freq = curSam.variables{iFreq}.data;
            istart_countdown = find(Freq < minCondFreq, 1, 'last') + 1; % finds the last index where CNDC freq is too low
            
            % should be in water but minCondFreq can be set too low
            if isempty(istart_countdown)
                istart_countdown = 1;
            else
                % if conductivity frequency is working use it to determine
                % better time in water - countdown uses last in water time
                % during downcast in case it briefly comes out of water
                % it is possible that surface soak is fine but pump is
                % still off - in this case values are considered good as
                % soon as pump turns on
                iin_water = find(Freq >= minCondFreq, 1, 'first');
            end
            
            time_pump_on = elapsed_time(istart_countdown) + pumpDelay;
            ipump_off = elapsed_time < time_pump_on;
        end
    end
    
    if ~isempty(elapsed_time);
        % soak time is relative to time in water based on pressure
        % no pump is required to calculate these terms
        timeTempMinSoak = elapsed_time(iin_water) + tempMinSoak;
        timeTempOptSoak = elapsed_time(iin_water) + tempOptSoak;
        
        timeCndMinSoak = elapsed_time(iin_water) + cndMinSoak;
        timeCndOptSoak = elapsed_time(iin_water) + cndOptSoak;
        
        timeOxMinSoak = elapsed_time(iin_water) + oxMinSoak;
        timeOxOptSoak = elapsed_time(iin_water) + oxOptSoak;
        
        qcSet = str2double(readProperty('toolbox.qc_set'));
        failFlag    = imosQCFlag('bad',         qcSet, 'flag');
        pBadFlag    = imosQCFlag('probablyBad', qcSet, 'flag');
        pGoodFlag   = imosQCFlag('probablyGood',qcSet, 'flag');
        goodFlag    = imosQCFlag('Good',        qcSet, 'flag');
        
        % all status is set to good by default
        tempSoakStatus = ones(length(press), 1, 'int8')*goodFlag;
        cndSoakStatus = tempSoakStatus;
        oxSoakStatus = tempSoakStatus;
        
        tempSoakStatus(elapsed_time < timeTempOptSoak) = pGoodFlag;
        tempSoakStatus(elapsed_time < timeTempMinSoak) = pBadFlag;
        
        cndSoakStatus(elapsed_time < timeCndOptSoak) = pGoodFlag;
        cndSoakStatus(elapsed_time < timeCndMinSoak) = pBadFlag;
        
        oxSoakStatus(elapsed_time < timeOxOptSoak) = pGoodFlag;
        oxSoakStatus(elapsed_time < timeOxMinSoak) = pBadFlag;
        
        if use_pump
            % pump status  will override previous soak_status flags if the
            % pump is off.
            % soak_status == 0, the pump is off and sensors fed by the pump
            % will be producing invalid data
            tempSoakStatus(ipump_off) = failFlag;
            cndSoakStatus(ipump_off) = failFlag;
            oxSoakStatus(ipump_off) = failFlag;
        end
    end
    
    DepthIdx    = getVar(curSam.dimensions, 'DEPTH');
    ProfileIdx = getVar(curSam.dimensions, 'PROFILE');
    dimensions  = [DepthIdx ProfileIdx];
    coordinates = '';
    flagComments = 'flags: fail = pump off, pBad before min soak, pGood after min but before optimal, good after optimal.';
    
    % add soak status data as new variable in data set
    sample_data{k} = addVar(...
        curSam, ...
        'tempSoakStatus', ...
        tempSoakStatus, ...
        dimensions, ...
        flagComments, ...
        coordinates);
    curSam = sample_data{k};
    
    sample_data{k} = addVar(...
        curSam, ...
        'cndSoakStatus', ...
        cndSoakStatus, ...
        dimensions, ...
        flagComments, ...
        coordinates);
    curSam = sample_data{k};
    
    sample_data{k} = addVar(...
        curSam, ...
        'oxSoakStatus', ...
        oxSoakStatus, ...
        dimensions, ...
        flagComments, ...
        coordinates);
    
    clear tempSoakStatus;    
    clear cndSoakStatus;   
    clear oxSoakStatus;
    clear curSam instHistory 
end
end