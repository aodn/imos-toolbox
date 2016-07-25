function [sample_data, varChecked, paramsLog] = imosTiltVelocitySetQC( sample_data, auto )
%IMOSTILTVELOCITYSETQC Quality control procedure for ADCP instrument data against their tilt.
%
% Quality control ADCP velocity data, assessing the tilt of the instrument.
%
% The tilt of the instrument plays into a number of factors:
%          -We need to know the tilt in order to convert from along the beam to 
%           horizontal and vertical components
%          -We need to know the tilt in order to map the bins from different 
%           beams to the same place in the water column
%          -The compass errors increase with increasing tilts.
%
% Finally, most tilt sensors output is scaled and reaches a maximum at
% some specific angle so that any measured angle equals or greater than this 
% maximum means that the measured velocity data is not reliable.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%   varChecked  - cell array of variables' name which have been checked
%   paramsLog   - string containing details about params' procedure to include in QC log
%
% More RDI details below from Darryl.Symonds@Teledyne.com on Thu 18/12/2014 :
%
% The Sentinel V, can provide tilts basically in full circle around the instrument. 
% The WorkHorse tilt sensor output is scaled and reaches a maximum at either :
%   ~22 degrees for Sentinel/Monitor, 
%   ~50 degrees for the Long Ranger and QuarterMaster.
%
% Coordinate Transformation
% -------------------------
% Converting from along the beams (radial) velocities to horizontal and vertical 
% components is done using the beam angle of the transducer +/- the tilt of the 
% instrument.  Very basic trigonometry is applied here.   If the instrument is 
% tilted over by more than the tilt sensors can measure then (i.e. >22degrees 
% in a WH) there is no way to resolve the math and so you no longer are sure 
% that the vertical component and horizontal component have been calculated 
% properly.  However, if you know something about the area that you are operating 
% in, and if the vertical component has a mean of zero with some shear up and 
% down the profile then you can look at your data and see if the vertical 
% velocities being reported are doing this.  If they are then you can “feel” 
% good about the data you have.  If however the vertical component appears to 
% be biased off of zero then you know that the tilts were exceeded by much more 
% than the maximum tilt reported and now you cannot trust the data.
%  
% Note this is all subjective and if you are trying to measure to the accuracy 
% of our specification then you pretty much cannot trust velocity data once 
% you reach the maximum tilt of the instrument. 
%  
% Bin Mapping
% -----------
% Our bin mapping algorithm uses the tilt data to make sure that the correct 
% bins along each the beams are used when creating the horizontal velocities. 
% If you have small tilts, say <5 degrees, then the there is very little “bin 
% mapping” required until you get very far away from the ADCP.    
%  
% To help illustrate this please picture the ADCP so that it tilts only on one 
% axis.  The tilt now is so great that one beam is horizontal.  It has no 
% vertical profile at all.  None of its bins will map to the position of the 
% other 3 beams that are pointing somewhat vertically in the water column.
%  
% Now as you have less tilt what you will see is that near bins map out in the 
%same vertical position for all 4 beams.  However, as you move further away 
% from the instrument the tilt magnifies the difference in vertical position 
% in the water column and causes one bin a particular beam to be lower than 
% another bin in a different / opposite beam.  
%  
% If the tilt sensor has reached its maximum then this bin mapping cannot be 
% accurately applied.  The result is that bins from different vertical depths 
% in the water may be used in the coordinate transformed data.  The result is 
% that the velocities are smeared over the depth of the instrument.   
%  
% Again, if you are trying to measure to the accuracy of our specification 
% then you pretty much cannot trust velocity data once you reach the maximum 
% tilt of the instrument.
%  
% Compass
% -------
% Our standard specification for our compass assumes the system will be with 
% tilts of around +/-15 degrees. The errors in the compass will increase beyond 
% this and can be in 10’s of degrees rather than the +/-2 degrees you can 
% achieve with the field calibration.     
%  
% The reason is that the flux gate compass is measuring the earth’s horizontal 
% magnetic field strength.  As you tilt the instrument over the sensors on the 
% compass are now pointing at a different angle relative the earth’s horizontal 
% magnetic field and less energy is actually measured. This is the same 
% phenomenon as what happens as you near the magnetic poles. The difference 
% is that the earth’s magnetic field is what is changing and at the poles the 
% magnetic field becomes vertical.
%
%
% The Nortek Principle of Operation document says :
%
% Page 19, chapter 1.1.6.3 Pitch, Roll and Heading
% ------------------------------------------------
% Tilt readings between 20° and 30° affect the data accuracy in a way that is 
% likely to make the data fail to meet the specifications. Data acquired during 
% tilts exceeding 30° are in general not reliable and should be discarded.
%
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

varChecked = {};
paramsLog  = [];

% get all necessary dimensions and variables id in sample_data struct
idUcur = 0;
idVcur = 0;
idWcur = 0;
idCspd = 0;
idCdir = 0;
idPitch = 0;
idRoll = 0;
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur    = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur    = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur    = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd    = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir    = i; end
    if strcmpi(paramName, 'PITCH'),     idPitch   = i; end
    if strcmpi(paramName, 'ROLL'),      idRoll    = i; end
end

% check if the data is compatible with the QC algorithm, otherwise quit
% silently
idMandatory = idPitch & idRoll & (idUcur | idVcur | idWcur | idCspd | idCdir);
if ~idMandatory, return; end

qcSet = str2double(readProperty('toolbox.qc_set'));
goodFlag = imosQCFlag('good', qcSet, 'flag');

% we try to find out which kind of ADCP we're dealing with and if it is
% listed as one we should process
instrument = sample_data.instrument;
if isfield(sample_data, 'meta')
    if isfield(sample_data.meta, 'instrument_make') && isfield(sample_data.meta, 'instrument_model')
        instrument = [sample_data.meta.instrument_make ' ' sample_data.meta.instrument_model];
    end
end
        
[firstTiltThreshold, secondTiltThreshold, firstFlagThreshold, secondFlagThreshold] = getTiltThresholds(instrument);

if isempty(firstTiltThreshold)
    % couldn't find this instrument so quit the test
    disp(['Info: imosTiltVelositySetQC could not be performed on ' sample_data.toolbox_input_file ...
        ' instrument = "' instrument '" => Fill imosTiltVelositySetQC.txt with relevant make/model information if you wish to run this test on this dataset.']);
    return;
end

paramsLog = ['firstTiltThreshold=' num2str(firstTiltThreshold) ', secondTiltThreshold=' num2str(secondTiltThreshold)];

pitch = sample_data.variables{idPitch}.data;
roll  = sample_data.variables{idRoll}.data;

tilt = acos(sqrt(1 - sin(roll*pi/180).^2 - sin(pitch*pi/180).^2))*180/pi;

% initially everything is failing the tests
if idUcur
    idVar = idUcur;
else
    idVar = idCspd;
end
sizeCur = size(sample_data.variables{idVar}.flags);
flags = ones(sizeCur, 'int8')*secondFlagThreshold;

% tilt test
iPass = tilt < secondTiltThreshold;
flags(iPass,:) = firstFlagThreshold;

iPass = tilt < firstTiltThreshold;
flags(iPass,:) = goodFlag;

if idWcur
    sample_data.variables{idWcur}.flags = flags;
    varChecked = [varChecked, {'WCUR'}];
end
if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {'CSPD'}];
end

if idUcur
    sample_data.variables{idUcur}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idUcur}.name}];
end
if idVcur
    sample_data.variables{idVcur}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idVcur}.name}];
end
if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end
end

function [firstTiltThreshold, secondTiltThreshold, firstTiltflag, secondTiltflag] = getTiltThresholds(instrument)
%GETTILTTHRESHOLDS Returns the 2-level ADCP tilt thresholds  and their
% associated flags according to the global attribute instrument provided.
%

firstTiltThreshold  = [];
secondTiltThreshold = [];
firstTiltflag  = [];
secondTiltflag = [];

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'AutomaticQC');

fid = -1;
params = [];
try
  fid = fopen([path filesep 'imosTiltVelocitySetQC.txt'], 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%f%f%d8%d8', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% look for an instrument match
for i=1:length(params{1})
    if ~isempty(strfind(lower(instrument), lower(params{1}{i})))
        firstTiltThreshold  = params{2}(i);
        secondTiltThreshold = params{3}(i);
        firstTiltflag  = params{4}(i);
        secondTiltflag = params{5}(i);
        return;
    end
end

end