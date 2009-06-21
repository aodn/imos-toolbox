function sample_data = workhorseParse( filename )
%WORKHORSEPARSE Parses a raw (binary) data file from a Teledyne RD Workhorse 
% ADCP.
%
% This function uses the readWorkhorseEnsembles function to read in a set
% of ensembles from a raw binary Workhorse ADCP file. It parses the 
% ensembles, and extracts and returns the following:
%   - time
%   - temperature (at each time)
%   - water speed (at each time and depth)
%   - water direction (at each time and depth)
% 
% Inputs:
%   filename    - raw binary data file retrieved from a Workhorse.
%
% Outputs:
%   sample_data - sample_data struct containing the data retrieved from the
%                 input file.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  
  % currently assuming that fixed leader 
  % data is the same for every ensemble
  fixed = ensembles{1}.fixedLeader;
    
  % we use these to set up variables and dimensions
  numBeams   = fixed.numBeams;
  numCells   = fixed.numCells;
  cellLength = fixed.depthCellLength;
  cellStart  = fixed.bin1Distance;
  
  % preallocate space for sample data
  time        = zeros(length(ensembles), 1);
  depth       = zeros(numCells,          1);
  speed       = zeros(length(ensembles), numCells);
  direction   = zeros(length(ensembles), numCells);
  temperature = zeros(length(ensembles), 1);
    
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
    
    % / 10.0, as the temperature samples are in steps of 0.01 degrees
    temperature(k) = variable.temperature / 100.0;
    
    % sometimes (e.g. on the last ensemble) 
    % there will be no velocity section. 
    if ~isfield(ensemble, 'velocity'), continue; end
    
    velocity = ensemble.velocity;
    
    %
    % calculate velocity (speed and direction)
    % currently assuming earth coordinate transform
    %
    veast = velocity.velocity1;
    vnrth = velocity.velocity2;
    
    % set all bad values to 0. might remove this later, 
    % but it makes viewing the data much easier
    vnrth(vnrth == -32768) = 0;
    veast(veast == -32768) = 0;
    
    % / 1000.0, as the velocity samples are in millimetres per second
    speed(k,:) = sqrt(vnrth.^2 + veast.^2) / 1000.0;
    
    % direction is in degrees clockwise from north
    direction(k,:) = atan(abs(veast ./ vnrth)) .* (180 / pi);
    
    se = vnrth <  0 & veast >= 0;
    sw = vnrth <  0 & veast <  0;
    nw = vnrth >= 0 & veast <  0;
    
    direction(k,se) = arrayfun(@(x)(180 - x), direction(k,se));
    direction(k,sw) = arrayfun(@(x)(180 + x), direction(k,sw));
    direction(k,nw) = arrayfun(@(x)(360 - x), direction(k,nw));
    
    direction(k,isnan(vnrth)) = 0;
  end
  
  % fill in the sample_data struct
  sample_data.meta.fixedLeader     = fixed;
  sample_data.instrument_make      = 'Teledyne RD';
  sample_data.instrument_model     = 'Workhorse ADCP';
  sample_data.instrument_serial_no =  num2str(fixed.instSerialNumber);
  sample_data.instrument_firmware  = [num2str(fixed.cpuFirmwareVersion) '.' ...
                                      num2str(fixed.cpuFirmwareRevision)];
                                    
  % add dimensions
  sample_data.dimensions{1}.name       = 'TIME';
  sample_data.dimensions{2}.name       = 'DEPTH';
  
  % add variables
  sample_data.variables{ 1}.name       = 'CSPD';
  sample_data.variables{ 2}.name       = 'CDIR';
  sample_data.variables{ 3}.name       = 'TEMP';
  
  % map dimensions to each variable
  sample_data.variables{ 1}.dimensions = [1 2];
  sample_data.variables{ 2}.dimensions = [1 2];
  sample_data.variables{ 3}.dimensions = [1];
  
  % copy all the data across
  sample_data.dimensions{1}.data       = time;
  sample_data.dimensions{2}.data       = depth;
  sample_data.variables{ 1}.data       = speed;
  sample_data.variables{ 2}.data       = direction;
  sample_data.variables{ 3}.data       = temperature;
end
