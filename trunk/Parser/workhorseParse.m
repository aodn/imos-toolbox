function sample_data = workhorseParse( filename )
%WORKHORSEPARSE Parses a raw (binary) data file from a Teledyne RD Workhorse 
% ADCP.
%
% This function uses the readWorkhorseEnsembles function to read in a set
% of ensembles from a raw binary Workhorse ADCP file. It parses the 
% ensembles, and extracts and returns the following:
%
%   - time
%   - temperature (at each time)
%   - pressure (at each time, if present)
%   - salinity (at each time, if present)
%   - water speed (at each time and depth)
%   - water direction (at each time and depth)
%   - Acoustic backscatter intensity (at each time and depth, a separate 
%     variable for each beam)
%
% The conversion from the ADCP velocity values currently assumes that the 
% ADCP is using earth coordinates (see section 13.4 'Velocity Data Format' 
% of the Workhorse H-ADCP Operation Manual).
% 
% Inputs:
%   filename    - raw binary data file retrieved from a Workhorse.
%
% Outputs:
%   sample_data - sample_data struct containing the data retrieved from the
%                 input file.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%         Leeying Wu <Wu.Leeying@saugov.sa.gov.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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
error(nargchk(1,1,nargin));

  ensembles = readWorkhorseEnsembles( filename{1} );
  
  if isempty(ensembles), error('no ensembles found in file'); end
  
  % currently we're only interested in velocity data
  ensembles = ensembles(cellfun(@(x)(isfield(x, 'velocity')), ensembles));
  
  % currently assuming that fixed leader 
  % data is the same for every ensemble
  fixed = ensembles{1}.fixedLeader;
    
  % we use these to set up variables and dimensions
  numBeams   = fixed.numBeams;
  numCells   = fixed.numCells;
  cellLength = fixed.depthCellLength;
  cellStart  = fixed.bin1Distance;
  
  % preallocate space for sample data
  time         = zeros(length(ensembles), 1);
  depth        = zeros(numCells,          1);
  vvel         = zeros(length(ensembles), numCells);
  uvel         = zeros(length(ensembles), numCells);
  speed        = zeros(length(ensembles), numCells);
  direction    = zeros(length(ensembles), numCells);
  backscatter1 = zeros(length(ensembles), numCells);
  backscatter2 = zeros(length(ensembles), numCells);
  backscatter3 = zeros(length(ensembles), numCells);
  backscatter4 = zeros(length(ensembles), numCells);
  correlation1 = zeros(length(ensembles), numCells);
  correlation2 = zeros(length(ensembles), numCells);
  correlation3 = zeros(length(ensembles), numCells);
  correlation4 = zeros(length(ensembles), numCells);
  percentGood1 = zeros(length(ensembles), numCells);
  percentGood2 = zeros(length(ensembles), numCells);
  percentGood3 = zeros(length(ensembles), numCells);
  percentGood4 = zeros(length(ensembles), numCells);
  temperature  = zeros(length(ensembles), 1);
  pressure     = zeros(length(ensembles), 1);
  salinity     = zeros(length(ensembles), 1);
  pitch        = zeros(length(ensembles), 1);
  roll         = zeros(length(ensembles), 1);
  heading      = zeros(length(ensembles), 1);
    
  % we can populate depth data now using cellLength and cellStart
  % ( / 100.0, as the ADCP gives the values in centimetres)
  cellStart  = cellStart  / 100.0;
  cellLength = cellLength / 100.0;
  
  depth(:) = (cellStart):  ...
             (cellLength): ...
             (cellStart + (numCells-1) * cellLength);
  
  % rearrange the sample data
  for k = 1:length(ensembles)
    
    ensemble = ensembles{k};
    
    % metadata for this ensemble
    variable = ensemble.variableLeader;
    
    time(k) = datenum(...
     [variable.y2kCentury*100 + variable.y2kYear,...
      variable.y2kMonth,...
      variable.y2kDay,...
      variable.y2kHour,...
      variable.y2kMinute,...
      variable.y2kSecond + variable.y2kHundredth/100.0]);
    
    %
    % auxillary data
    %
    temperature(k) = variable.temperature;
    pressure   (k) = variable.pressure;
    salinity   (k) = variable.salinity;
    pitch      (k) = variable.pitch;
    roll       (k) = variable.roll;
    heading    (k) = variable.heading;
    
    %
    % calculate velocity (speed and direction)
    % currently assuming earth coordinate transform
    %
    velocity = ensemble.velocity;
    veast = velocity.velocity1;
    vnrth = velocity.velocity2;
    
    % set all bad values to nan. 
    vnrth(vnrth == -32768) = nan;
    veast(veast == -32768) = nan;
    
    vvel(k,:) = vnrth;
    uvel(k,:) = veast;
    
    speed(k,:) = sqrt(vnrth.^2 + veast.^2);
    
    % direction is in degrees clockwise from north
    direction(k,:) = atan(abs(veast ./ vnrth)) .* (180 / pi);
    
    se = vnrth <  0 & veast >= 0;
    sw = vnrth <  0 & veast <  0;
    nw = vnrth >= 0 & veast <  0;
    
    direction(k,se) = arrayfun(@(x)(180 - x), direction(k,se));
    direction(k,sw) = arrayfun(@(x)(180 + x), direction(k,sw));
    direction(k,nw) = arrayfun(@(x)(360 - x), direction(k,nw));
    
    %
    % retrieve backscatter, correlation and percent good data 
    %
    backscatter1(k,:) = ensemble.echoIntensity.field1;
    backscatter2(k,:) = ensemble.echoIntensity.field2;
    backscatter3(k,:) = ensemble.echoIntensity.field3;
    backscatter4(k,:) = ensemble.echoIntensity.field4;
    
    correlation1(k,:) = ensemble.corrMag.field1;
    correlation2(k,:) = ensemble.corrMag.field2;
    correlation3(k,:) = ensemble.corrMag.field3;
    correlation4(k,:) = ensemble.corrMag.field4;
    
    percentGood1(k,:) = ensemble.percentGood.field1;
    percentGood2(k,:) = ensemble.percentGood.field2;
    percentGood3(k,:) = ensemble.percentGood.field3;
    percentGood4(k,:) = ensemble.percentGood.field4;
  end
  
  %
  % temperature / 100.0  (0.01 deg   -> deg)
  % pressure    * 1000.0 (decapascal -> decibar)
  % vvel        / 1000.0 (mm/s       -> m/s)
  % uvel        / 1000.0 (mm/s       -> m/s)
  % speed       / 1000.0 (mm/s       -> m/s)
  % backscatter * 0.45   (count      -> dB)
  % pitch       / 100.0 (0.01 deg    -> deg)
  % roll        / 100.0 (0.01 deg    -> deg)
  % heading     / 100.0 (0.01 deg    -> deg)
  % no conversion for salinity - i'm treating 
  % ppt and PSU as interchangeable
  %
  temperature  = temperature  / 100.0;
  pressure     = pressure     * 1000.0;
  vvel         = vvel         / 1000.0;
  uvel         = uvel         / 1000.0;
  speed        = speed        / 1000.0;
  backscatter1 = backscatter1 * 0.45;
  backscatter2 = backscatter2 * 0.45;
  backscatter3 = backscatter3 * 0.45;
  backscatter4 = backscatter4 * 0.45;
  pitch        = pitch        / 100.0;
  roll         = roll         / 100.0;
  heading      = heading      / 100.0;
  
  % fill in the sample_data struct
  sample_data.meta.fixedLeader          = fixed;
  sample_data.meta.instrument_make      = 'Teledyne RD';
  sample_data.meta.instrument_model     = 'Workhorse ADCP';
  sample_data.meta.instrument_serial_no =  num2str(fixed.instSerialNumber);
  sample_data.meta.instrument_firmware  = ...
    [num2str(fixed.cpuFirmwareVersion) '.' num2str(fixed.cpuFirmwareRevision)];
                                    
  % add dimensions
  sample_data.dimensions{1}.name       = 'TIME';
  sample_data.dimensions{2}.name       = 'DEPTH';
  
  % add variables
  sample_data.variables{ 1}.name       = 'VCUR';
  sample_data.variables{ 2}.name       = 'UCUR';
  sample_data.variables{ 3}.name       = 'CSPD';
  sample_data.variables{ 4}.name       = 'CDIR';
  sample_data.variables{ 5}.name       = 'ABSI_1';
  sample_data.variables{ 6}.name       = 'ABSI_2';
  sample_data.variables{ 7}.name       = 'ABSI_3';
  sample_data.variables{ 8}.name       = 'ABSI_4';
  sample_data.variables{ 9}.name       = 'TEMP';
  sample_data.variables{10}.name       = 'PRES';
  sample_data.variables{11}.name       = 'PSAL';
  sample_data.variables{12}.name       = 'ADCP_CORR_1';
  sample_data.variables{13}.name       = 'ADCP_CORR_2';
  sample_data.variables{14}.name       = 'ADCP_CORR_3';
  sample_data.variables{15}.name       = 'ADCP_CORR_4';
  sample_data.variables{16}.name       = 'ADCP_GOOD_1';
  sample_data.variables{17}.name       = 'ADCP_GOOD_2';
  sample_data.variables{18}.name       = 'ADCP_GOOD_3';
  sample_data.variables{19}.name       = 'ADCP_GOOD_4';
  sample_data.variables{20}.name       = 'PITCH';
  sample_data.variables{21}.name       = 'ROLL';
  sample_data.variables{22}.name       = 'HEADING';
  
  % map dimensions to each variable
  sample_data.variables{ 1}.dimensions = [1 2];
  sample_data.variables{ 2}.dimensions = [1 2];
  sample_data.variables{ 3}.dimensions = [1 2];
  sample_data.variables{ 4}.dimensions = [1 2];
  sample_data.variables{ 5}.dimensions = [1 2];
  sample_data.variables{ 6}.dimensions = [1 2];
  sample_data.variables{ 7}.dimensions = [1 2];
  sample_data.variables{ 8}.dimensions = [1 2];
  sample_data.variables{ 9}.dimensions = [1];
  sample_data.variables{10}.dimensions = [1];
  sample_data.variables{11}.dimensions = [1];
  sample_data.variables{12}.dimensions = [1 2];
  sample_data.variables{13}.dimensions = [1 2];
  sample_data.variables{14}.dimensions = [1 2];
  sample_data.variables{15}.dimensions = [1 2];
  sample_data.variables{16}.dimensions = [1 2];
  sample_data.variables{17}.dimensions = [1 2];
  sample_data.variables{18}.dimensions = [1 2];
  sample_data.variables{19}.dimensions = [1 2];
  sample_data.variables{20}.dimensions = [1];
  sample_data.variables{21}.dimensions = [1];
  sample_data.variables{22}.dimensions = [1];
  
  % copy all the data across
  sample_data.dimensions{1}.data       = time;
  sample_data.dimensions{2}.data       = depth;
  
  sample_data.variables{ 1}.data       = vvel;
  sample_data.variables{ 2}.data       = uvel;
  sample_data.variables{ 3}.data       = speed;
  sample_data.variables{ 4}.data       = direction;
  sample_data.variables{ 5}.data       = backscatter1;
  sample_data.variables{ 6}.data       = backscatter2;
  sample_data.variables{ 7}.data       = backscatter3;
  sample_data.variables{ 8}.data       = backscatter4;
  sample_data.variables{ 9}.data       = temperature;
  sample_data.variables{10}.data       = pressure;
  sample_data.variables{11}.data       = salinity;
  sample_data.variables{12}.data       = correlation1;
  sample_data.variables{13}.data       = correlation2;
  sample_data.variables{14}.data       = correlation3;
  sample_data.variables{15}.data       = correlation4;
  sample_data.variables{16}.data       = percentGood1;
  sample_data.variables{17}.data       = percentGood2;
  sample_data.variables{18}.data       = percentGood3;
  sample_data.variables{19}.data       = percentGood4;
  sample_data.variables{20}.data       = pitch;
  sample_data.variables{21}.data       = roll;
  sample_data.variables{22}.data       = heading;
  
  % remove auxillary data if the sensors 
  % were not installed on the instrument
  hasPres    = bitand(fixed.sensorsAvailable, 32);
  hasHeading = bitand(fixed.sensorsAvailable, 16);
  hasPitch   = bitand(fixed.sensorsAvailable, 8);
  hasRoll    = bitand(fixed.sensorsAvailable, 4);
  hasPsal    = bitand(fixed.sensorsAvailable, 2);
  hasTemp    = bitand(fixed.sensorsAvailable, 1); 

  % indices of variables to remove
  remove = [];
  
  if ~hasPres,    remove(end+1) = getVar(sample_data.variables, 'PRES');    end
  if ~hasHeading, remove(end+1) = getVar(sample_data.variables, 'HEADING'); end
  if ~hasPitch,   remove(end+1) = getVar(sample_data.variables, 'PITCH');   end
  if ~hasRoll,    remove(end+1) = getVar(sample_data.variables, 'ROLL');    end
  if ~hasPsal,    remove(end+1) = getVar(sample_data.variables, 'PSAL');    end
  if ~hasTemp,    remove(end+1) = getVar(sample_data.variables, 'TEMP');    end
  
  % also remove empty backscatter and correlation data
  for k = 4:-1:numBeams+1
    remove(end+1) = getVar(sample_data.variables, ['ABSI_' num2str(k)]);
    remove(end+1) = ...
      getVar(sample_data.variables, ['ABSI_CORR_' num2str(k)]);
  end
  
  sample_data.variables(remove) = [];
  
end