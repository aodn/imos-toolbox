function imosCompile()
%IMOSCOMPILE builds standalone binaries.
%
% This function uses the Matlab Compiler to compile the toolbox code.
%
% This function must be executed from the root of the toolbox directory 
% tree that is to be compiled. As part of the compilation process, a 'staging' 
% directory is created at the same level as the toolbox directory tree.
% For example, if the toolbox tree is located in 'C:\matlab\toolbox',
% the following directory will be created:
%
%   - 'C:\matlab\staging'
%
% If this directory already exists, the function will fail.
% This directory is deleted after compilation. The resulting executable binary 
% file, named 'imos-toolbox.exe', is created from the 'imos-toolbox' 
% directory, and will be stored in the root of the toolbox directory tree 
% (i.e. the directory that the function was called from).
%
% If you wish to modify the toolbox, you must execute the 
% toolbox from the source, which requires a Matlab license.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% assume we are running from snapshot/export (see
% snapshot/buildBinaries.py)
exportRoot    = pwd;
toolboxRoot   = [exportRoot filesep '..' filesep '..'];
stagingRoot   = [exportRoot filesep '..' filesep 'staging'];

if ~isempty(dir(stagingRoot)),   error([stagingRoot   ' already exists']); end

% create a directory to put 
% the compiled file(s) - the staging area
disp(['creating staging area: ' stagingRoot]);
if ~mkdir(stagingRoot), error('could not create staging area'); end

% find all .m and .mat files - these are to be 
% included as resources in the standalone application 
matlabFiles     = fsearchRegexp('.m$',   exportRoot, 'files');
matlabDataFiles = fsearchRegexp('.mat$', exportRoot, 'files');

% we leave out imosToolbox.m because, as the main 
% function, it must be listed first.
iMainFile = strcmpi(matlabFiles, fullfile(exportRoot, 'imosToolbox.m'));
matlabFiles(iMainFile) = [];

% compile the compiler options
cflags{1}     =  '-m';                      % generate a standalone application

myComputer = computer();
if strcmpi(myComputer, 'PCWIN')
    architecture = 'Win32';
elseif strcmpi(myComputer, 'PCWIN64')
    architecture = 'Win64';
elseif strcmpi(myComputer, 'GLNXA64')
    architecture = 'Linux64';
end

outputName = ['imosToolbox_' architecture];

cflags{end+1} = ['-o ''' outputName ''''];  % specify output name
cflags{end+1} = ['-d ''' stagingRoot '''']; % specified directory for output
cflags{end+1} =  '-v';                      % verbose
cflags{end+1} =  '-N';                      % clear path
cflags{end+1} =  '-w enable';               % enable complete warning display
% cflags{end+1} =  '-e';                      % disable MS-Dos command window outputs

% add matlab files to the compiler args
cflags{end+1} = ['''' exportRoot filesep 'imosToolbox.m'''];
for k = 1:length(matlabFiles)
  cflags{end+1} = ['''' matlabFiles{k} '''']; 
end
for k = 1:length(matlabDataFiles)
  cflags{end+1} = ['-a ''' matlabDataFiles{k} '''']; 
end

% print out options
disp('-- mcc options --');
for k = 1:length(cflags), disp(cflags{k}); end
disp('----');

% turn options into a single, space-separated string
cflags = cellfun(@(x)([x ' ']), cflags, 'UniformOutput', false);
cflags = [cflags{:}];

% run mcc; i can't call mcc like 'mcc(cflags)'. it gives me 
% some nonsensical error about '-x is no longer supported'
eval(['mcc ' cflags]);

% copy the compiled application over to the working project directory
if any(strcmpi(myComputer, {'PCWIN', 'PCWIN64'}))
    if ~copyfile([stagingRoot filesep outputName '.exe'], toolboxRoot)
        error(['could not copy ' outputName '.exe to working project area']);
    end
elseif strcmpi(myComputer, 'GLNXA64')
    if ~copyfile([stagingRoot filesep outputName], [toolboxRoot filesep outputName '.bin'])
        error(['could not copy ' outputName '.bin to working project area']);
    end
%     if ~copyfile([stagingRoot filesep 'run_' outputName '.sh'], [toolboxRoot filesep outputName '.sh'])
%         error(['could not copy ' linuxOutputNameRad '.sh to working project area']);
%     end
end

% copy the previously built ddb.jar before cleaning
if ~copyfile([exportRoot filesep 'Java' filesep 'ddb.jar'], [toolboxRoot filesep 'Java'])
    error('could not copy ddb.exe to working project area');
end

% clean up
rmdir(stagingRoot,   's');
