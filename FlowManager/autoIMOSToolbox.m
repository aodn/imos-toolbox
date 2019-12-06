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
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(1, 6);

% get the toolbox execution mode.
mode = readProperty('toolbox.mode');
    
% validate and save field trip
if nargin > 1
    if isnumeric(fieldTrip), error('field trip must be a string'); end
    writeProperty(['startDialog.fieldTrip.' mode], fieldTrip);
else
    try
        fieldTrip = readProperty(['startDialog.fieldTrip.' mode]);
    catch e
    end
end

% validate and save data dir
if nargin > 2
    if ~ischar(dataDir),       error('dataDir must be a string');    end
    if ~exist(dataDir, 'dir'), error('dataDir must be a directory'); end

    writeProperty(['startDialog.dataDir.' mode], dataDir);
else
    try
        dataDir = readProperty(['startDialog.dataDir.' mode]);
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
    
    writeProperty(['preprocessManager.preprocessChain.' mode], ppChainStr);
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
    
    writeProperty(['autoQCManager.autoQCChain.' mode], qcChainStr);
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

% get infos from current field trip
switch mode
    case 'profile'
        [~, deps, sits, dataDir] = getCTDs(true);
    case 'timeSeries'
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
    qc_data  = preprocessManager(sample_data, 'qc',  mode, true);
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