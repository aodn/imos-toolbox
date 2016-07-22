function imosPackage()
%IMOSPACKAGE Packages a standalone version of the toolbox.
%
% This function creates a zip file containing the toolbox binaries, source, and
% configuration files. Users are able to extract this zip file, and run the
% toolbox on computers which do not have Matlab installed. The Matlab
% Component Runtime must be installed though.
%
% This function must be executed from the root of the toolbox directory 
% tree that is to be compiled. As part of the compilation process, two 
% directories are created at the same level as the toolbox directory tree: 
% 'staging', and 'imos-toolbox'. For example, if the toolbox tree is located 
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
% Author:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% assume we are running from the toolbox root
toolboxRoot   = pwd;
packagingRoot = [toolboxRoot filesep '..' filesep 'imos-toolbox'];
stagingRoot   = [toolboxRoot filesep '..' filesep 'staging'];

if ~isempty(dir(packagingRoot)), error([packagingRoot ' already exists']); end
if ~isempty(dir(stagingRoot)),   error([stagingRoot   ' already exists']); end

% create a directory from which the resulting zip file will
% be generated - the packaging area, and a directory to put 
% the compiled file(s) - the staging area
disp(['creating packaging area: ' packagingRoot]);
if ~mkdir(packagingRoot), error('could not create packaging area'); end

disp(['creating staging area: ' stagingRoot]);
if ~mkdir(stagingRoot), error('could not create staging area'); end

% find all .m, .mat, .txt, .jar, .bat, .exe, .bin and .sh files - these are to be 
% included as resources in the standalone application 
matlabFiles     = fsearchRegexp('.m$',   toolboxRoot, 'files');
matlabDataFiles = fsearchRegexp('.mat$', toolboxRoot, 'files');
resourceFiles   = [matlabFiles   matlabDataFiles];
resourceFiles   = [resourceFiles fsearchRegexp('.txt$', toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.COF$', toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.jar$', toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.bat$', toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.exe$', toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.sh$',  toolboxRoot, 'files')];
resourceFiles   = [resourceFiles fsearchRegexp('.bin$', toolboxRoot, 'files')];

% copy the resource files to the packaging area
for k = 1:length(resourceFiles)

  f = resourceFiles{k};

  % get the name of the directory to create in the packaging area, 
  % by replacing the toolboxRoot prefix with the packagingRoot prefix
  fpath = strrep(f, toolboxRoot, packagingRoot);
  fpath = fileparts(fpath);

  % create directory in packaging area - mkdir warns, but 
  % returns success if the new directory already exists
  [stat, msg, id] = mkdir(fpath);
  if ~stat, error(['could not create directory: ' fpath]); end

  % copy the resource file over to the packaging area
  disp(['copying resource ' f ' to packaging area']);
  [stat, msg, id] = copyfile(f, fpath);
  if ~stat, error(['could not copy resource to packaging area: ' f]); end
end

% create a zip file containing the standalone 
% application and all required resources
disp(['creating toolbox archive: ' packagingRoot filesep 'imos-toolbox.zip']);
zip('imos-toolbox.zip', packagingRoot);

% clean up
rmdir(stagingRoot,   's');
rmdir(packagingRoot, 's');
