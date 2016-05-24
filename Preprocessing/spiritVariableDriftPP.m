function sample_data = spiritVariableDriftPP(sample_data, qcLevel, auto)
%SPIRITVARIABLEDRIFTPP Prompts the user to apply a variable drift correction to the given data 
% sets.
%
% Inputs:
%   sample_data - cell array of structs, the data sets to which time
%                 correction should be applied.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, with drift correction applied.
%

%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

narginchk(2,3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

isQC = false;
stringQC = 'non QC';

% get all params that are in common in at least two datasets
lenSampleData = length(sample_data);
paramsName = {};
paramsCount = [];
for i=1:lenSampleData
    lenParamsSample = length(sample_data{i}.variables);
    for j=1:lenParamsSample
        if i==1 && j==1
            paramsName{1} = sample_data{1}.variables{1}.name;
            paramsCount(1) = 1;
        else
            sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
            if ~any(sameParam)
                paramsName{end+1} = sample_data{i}.variables{j}.name;
                paramsCount(end+1) = 1;
            else
                paramsCount(sameParam) = paramsCount(sameParam)+1;
            end
        end
    end
end

iParamsToGetRid = (paramsCount == 1);
paramsName(iParamsToGetRid) = [];

% we get rid of TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE and NOMINAL_DEPTH parameters
iParam = strcmpi(paramsName, 'TIMESERIES');
paramsName(iParam) = [];
iParam = strcmpi(paramsName, 'PROFILE');
paramsName(iParam) = [];
iParam = strcmpi(paramsName, 'TRAJECTORY');
paramsName(iParam) = [];
iParam = strcmpi(paramsName, 'LATITUDE');
paramsName(iParam) = [];
iParam = strcmpi(paramsName, 'LONGITUDE');
paramsName(iParam) = [];
iParam = strcmpi(paramsName, 'NOMINAL_DEPTH');
paramsName(iParam) = [];

for iName = 1:length(paramsName)
    varName = paramsName{iName};
    
    exportDir = readProperty('exportDialog.defaultDir');
    
    [hFigTransectsVar, linearFit, quadraFit] = lineTransectsAsTimeseriesVar(sample_data, varName, isQC, true, exportDir);
    
    % Construct a questdlg with three options
    choice = questdlg(['Shall we correct ' varName ' for drift?'], ...
        'Variable drift correction', ...
        'Linear','Quadratic','No','No');
    
    close(hFigTransectsVar);
    
    % Handle response
    switch choice
        case 'Linear'
            fit = linearFit;
            equationStr = [num2str(fit.coef(1)) ' x'];
        case 'Quadratic'
            fit = quadraFit;
            equationStr = [num2str(fit.coef(1)) ' x^2 + ' num2str(fit.coef(2)) ' x'];
        case 'No'
            continue;
    end
    
    timeIdx = getVar(sample_data{1}.dimensions, 'TIME');
    firstTimeValue = sample_data{1}.dimensions{timeIdx}.data(1);
    
    firstVarQuadraFit = polyval(fit.coef, 0, fit.S, fit.mu);
    
    for k = 1:length(sample_data)
        [~, fileName, ext] = fileparts(sample_data{k}.toolbox_input_file);
        
        timeIdx = getVar(sample_data{k}.dimensions, 'TIME');
        time = sample_data{k}.dimensions{timeIdx}.data;
        
        scaledTime = [0; cumsum(diff(time))];
        scaledTime = scaledTime + (time(1) - firstTimeValue);
        
        varQuadraFit = polyval(fit.coef, scaledTime, fit.S, fit.mu);
        correction = varQuadraFit - firstVarQuadraFit;
        
        varIdx = getVar(sample_data{k}.variables, varName);
        varData = sample_data{k}.variables{varIdx}.data;
        varCorr = varData - correction;
        
        if any(varCorr < 0)
            disp(['Warning: spiritVariableDriftPP.m computed negative values for ' varName ' in ' fileName ext '!']);
        end
        
        sample_data{k}.variables{varIdx}.data = varCorr;
        
        dateFmt = readProperty('exportNetCDF.dateFormat');
        
        commentVariableDrift = ['spiritVariableDriftPP.m: correction = ' ...
            equationStr ' has been applied for drift with x = 0 when TIME is ' ...
            datestr(firstTimeValue, dateFmt)];
        
        comment = sample_data{k}.variables{varIdx}.comment;
        sample_data{k}.variables{varIdx}.comment = strtrim([comment ' ' commentVariableDrift]);
    end
end
end