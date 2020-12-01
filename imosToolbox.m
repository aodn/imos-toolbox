function imosToolbox(auto, varargin)
%IMOSTOOLBOX Starts the IMOS toolbox.
%
% This function is the entry point for the IMOS toolbox.
%
% Inputs:
%   auto     - optional String parameter - if 'version', the version of the
%              toolbox is output. if 'auto', the toolbox is executed
%              automatically, with no user interaction. Any other string will
%              result in the toolbox being executed normally.
%   varargin - In 'auto' mode, any other parameters passed in are passed
%              through to the autoIMOSToolbox function - see the
%              documentation for that function for details.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: Gordon Keith <gordon.keith@csiro.au>
%    -now adds any .jar found in Java directory to the path so that any driver
%    can be used to connect to a deployment database for example.
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

% Set current toolbox version
toolboxVersion = ['2.6.10 - ' computer];

if nargin == 0, auto = 'manual'; end

if strcmpi(auto, 'version')
    disp(toolboxVersion);
    return;
end

path = '';
if ~isdeployed
    [path, ~, ~] = fileparts(which('imosToolbox.m'));
    % set Matlab path for this session (add all recursive directories to Matlab
    % path)
    addpath(fullfile(path,'Util/Path'));
    addpath(fullfile(path,'Util/CellUtils'));
    addpath(fullfile(path,'Util/Schema'));

    [~,subfolders] = FilesInFolder(path);
    ignored_subfolders = {'.git','.mypy_cache','imos-toolbox/snapshot','imos-toolbox/data','imos-toolbox/dist'};
    [~,ignore_indexes] = inCellPartialMatchString(subfolders,ignored_subfolders);
    valid_subfolders = popFromCell(subfolders,subfolders([ignore_indexes{:}]));

    rmpath(fullfile(path,'Util/Path'));
    rmpath(fullfile(path,'Util/CellUtils'));
    rmpath(fullfile(path,'Util/Schema'));

    cell_of_folders_strings = cellfun(@genpath,valid_subfolders,'UniformOutput',false);
    all_folders_as_string= cat(2,cell_of_folders_strings{:});
    addpath(path);
    addpath(all_folders_as_string);
end
if isempty(path), path = pwd; end

% we must dynamically add the ddb.jar java library to the classpath
% as well as any other .jar library and jdbc drivers
jars = fsearchRegexp('.jar$', fullfile(path, 'Java'), 'files');
for j = 1 : length(jars)
    javaaddpath(jars{j});
end

switch auto
  case 'auto',    autoIMOSToolbox(toolboxVersion, varargin{:});
  otherwise,      flowManager(toolboxVersion);
end
