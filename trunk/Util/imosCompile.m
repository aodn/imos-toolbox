function imosCompile()
%IMOSCOMPILE Compiles a standalone version of the toolbox.
%
% This function uses the Matlab Compiler to compile the toolbox code, and
% creates a zip file containing the toolbox executable, source, and
% configuration files. Users are able to extract this zip file, and run the
% toolbox on Windows computers which do not have Matlab installed. This
% function has only been tested on Windows XP.
%
% This function must be executed from the root of the toolbox directory 
% tree that is to be compiled. As part of the compilation process, two 
% directories are created at the same level as the toolbox directory tree, 
%'staging', and 'imos-toolbox'. For example, if the toolbox tree is located 
% in 'C:\matlab\toolbox', the following directories will be created:
%
%   - 'C:\matlab\staging'
%   - 'C:\matlab\imos-toolbox'
%
% If either of these directories already exist, the function will fail.
% These directories are deleted after compilation. The resulting zip 
% file, named 'imos-toolbox.zip', is created from the 'imos-toolbox' 
% directory, and will be stored in the root of the toolbox directory tree 
% (i.e. the directory that the function was called from).
%
% The source code is included in the zip file because certain parts of the
% toolbox rely upon the existence of the Matlab source files. For example,
% the listParsers function scans the contents of the Parsers subdirectory
% to determine which parser functions are available. It is important to
% note that modifying these source files will not have any effect upon the 
% execution of the toolbox; all of the source files are compiled into the 
% executable. If you wish to modify the toolbox, you must execute the 
% toolbox from the source, which requires a Matlab license.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% assume we are running from the export root (see
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
matlabDataFiles = fsearch('.mat', exportRoot, 'files');

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

outputName = ['imosToolbox-' architecture];

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
if any(strcmpi(architecture, {'PCWIN', 'PCWIN64'}))
    if ~copyfile([stagingRoot filesep outputName '.exe'], toolboxRoot)
        error(['could not copy ' outputName '.exe to working project area']);
    end
elseif strcmpi(architecture, 'GLNXA64')
    if ~copyfile([stagingRoot filesep outputName], toolboxRoot)
        error(['could not copy ' outputName ' to working project area']);
    end
    if ~copyfile([stagingRoot filesep outputName '.sh'], toolboxRoot)
        error(['could not copy ' outputName '.sh to working project area']);
    end
end

% clean up
rmdir(stagingRoot,   's');
