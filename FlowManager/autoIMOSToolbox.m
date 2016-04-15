function autoIMOSToolbox(toolboxVersion, fieldTrip, dataDir, ppChain, qcChain, exportDir)
%AUTOIMOSTOOLBOX Executes the toolbox automatically.
%
% All inputs are optional.
%
% Inputs:
%   toolboxVersion  - string containing the current version of the toolbox.
%   parent          - handle to parent figure/uipanel.
%   fieldTrip       - Unique string ID of field trip. 
%   dataDir         - Directory containing raw data files.
%   ppChain         - Cell array of strings, the names of pre-process to run.
%   qcChain         - Cell array of strings, the names of QC filters to run.
%   exportDir       - Directory to store output files.
%
%   if no PP/QC then provide empty cell array {} for ppChain/qcChain
%
% Can be called from imosToolbox executable
%
%   Standalone : imosToolbox.exe auto "4788" "C:\Raw Data\" "{'timeOffset'}" ...
%           "{'inWaterQC' 'outWaterQC'}" "C:\NetCDF\"
%
%   Matlab script : imosToolbox auto 4788 'C:\Raw Data\' {'timeOffset'} ...
%           {'inWaterQC' 'outWaterQC'} 'C:\NetCDF\'
%
%                   or,
%
%                   imosToolbox('auto', '4788', 'C:\Raw Data\', '{''timeOffset''}' ...
%           '{''inWaterQC'' ''outWaterQC''}', 'C:\NetCDF\')
%
%   Using toolboxProperties.txt : imosToolbox auto
%
% Author:		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Brad Morris <b.morris@unsw.edu.au>
%				Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(1, 6);

% get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
% If no value is set then default mode is 'timeSeries'
mode = lower(readProperty('toolbox.mode'));
    
% validate and save field trip
if nargin > 1
    if isnumeric(fieldTrip), error('field trip must be a string'); end
    switch mode
        case 'profile'
            writeProperty('startDialog.fieldTrip.profile', fieldTrip);
        otherwise
            writeProperty('startDialog.fieldTrip.timeSeries', fieldTrip);
    end
else
    try
        switch mode
            case 'profile'
                fieldTrip = readProperty('startDialog.fieldTrip.profile');
            otherwise
                fieldTrip = readProperty('startDialog.fieldTrip.timeSeries');
        end
    catch e
    end
end

% validate and save data dir
if nargin > 2
    if ~ischar(dataDir),       error('dataDir must be a string');    end
    if ~exist(dataDir, 'dir'), error('dataDir must be a directory'); end

    switch mode
        case 'profile'
            writeProperty('startDialog.dataDir.profile', dataDir);
        otherwise
            writeProperty('startDialog.dataDir.timeSeries', dataDir);
    end
else
    try
        switch mode
            case 'profile'
                dataDir = readProperty('startDialog.dataDir.profile');
            otherwise
                dataDir = readProperty('startDialog.dataDir.timeSeries');
        end
    catch e
    end
end

% validate and save pp chain
if nargin > 3
    if ischar(ppChain)
        try
            [~] = evalc(['ppChain = ' ppChain]);
        catch e
            error('ppChain must be a cell array of strings');
        end
    end
    
    if ~iscellstr(ppChain)
        error('ppChain must be a cell array of strings');
    end
    
    if ~isempty(ppChain)
        ppChainStr = cellfun(@(x)([x ' ']), ppChain, 'UniformOutput', false);
        ppChainStr = deblank([ppChainStr{:}]);
    else
        ppChainStr = '';
    end
    
    switch mode
        case 'profile'
            writeProperty('preprocessManager.preprocessChain.profile', ppChainStr);
        otherwise
            writeProperty('preprocessManager.preprocessChain.timeSeries', ppChainStr);
    end
end

% validate and save qc chain
if nargin > 4
    if ischar(qcChain)
        try
            [~] = evalc(['qcChain = ' qcChain]);
        catch e
            error('qcChain must be a cell array of strings');
        end
    end
    
    if ~iscellstr(qcChain)
        error('qcChain must be a cell array of strings');
    end
    
    if ~isempty(qcChain)
        qcChainStr = cellfun(@(x)([x ' ']), qcChain, 'UniformOutput', false);
        qcChainStr = deblank([qcChainStr{:}]);
    else
        qcChainStr = '';
    end
    
    switch mode
        case 'profile'
            writeProperty('autoQCManager.autoQCChain.profile', qcChainStr);
        otherwise
            writeProperty('autoQCManager.autoQCChain.timeSeries', qcChainStr);
    end
end

% validate and save export dir
if nargin > 5
    if ~ischar(exportDir),       error('exportDir must be a string');    end
    if ~exist(exportDir, 'dir'), mkdir(exportDir); end
    
    writeProperty('exportDialog.defaultDir', exportDir);
else
    try
        exportDir = readProperty('exportDialog.defaultDir');
    catch e
    end
end

% import, pre-processing, QC and export
% moorings by moorings for the current field trip.
[~, sourceFolder] = fileparts(dataDir);
fprintf('%s\n', ['Processing field trip ' fieldTrip ' from folder ' sourceFolder]);

% get the toolbox execution mode. Values can be 'timeSeries' and 'profile'. 
% If no value is set then default mode is 'timeSeries'
mode = lower(readProperty('toolbox.mode'));

% get infos from current field trip
switch mode
    case 'profile'
        [~, deps, sits, dataDir] = getCTDs(true);
    otherwise
        [~, deps, sits, dataDir] = getDeployments(true);
end

if isempty(deps)
    fprintf('%s\n', ['Warning : ' 'No entry found in ' mode ' table.']);
    return;
end

moorings = {deps.Site}';
distinctMooring = unique(moorings);
lenMooring = length(distinctMooring);

for i=1:lenMooring
    fprintf('%s\n', ['Importing ' mode ' set of deployments ' distinctMooring{i} ' : ']);
    iMooring = strcmpi(distinctMooring(i), moorings);
    
    sample_data = importManager(toolboxVersion, true, iMooring);
    
    if isempty(sample_data), continue; end
    
    raw_data = preprocessManager(sample_data, 'raw', mode, true);
    qc_data  = preprocessManager(raw_data, 'qc', mode, true);
    clear sample_data;
    qc_data  = autoQCManager(qc_data, true);
    
    [~, targetFolder] = fileparts(exportDir);
    fprintf('%s', ['Writing ' distinctMooring{i} ' to folder ' targetFolder ' : '])

    exportManager({raw_data}, {'raw'}, 'netcdf', true);
    clear raw_data; % important, otherwise memory leak leads to crash
    if qc_data{1}.meta.level == 1
        exportManager({qc_data}, {'QC'}, 'netcdf', true);
        clear qc_data; % important, otherwise memory leak leads to crash
    end
    fprintf('%s\n', 'done.')
end
disp(' ');