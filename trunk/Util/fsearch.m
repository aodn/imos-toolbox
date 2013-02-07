function hits = fsearch(pattern, root, restriction)
%FSEARCH Recursive file/directory search.
%
% Performs a recursive search starting at the given root directory; returns
% the names of all files and directories below the root which have a name
% matching the given string pattern using strfind(). The name comparison is case 
% insensitive for alphabetical characters.
%
% Inputs:
%
%   pattern     - Pattern to match. Can be a filename, a full path or part
%                 of a path including a filename.
%
%   root        - Directory from which to start the search.
%
%   restriction - Optional. Either 'files' or 'dirs', to restrict the search 
%                 results to contain only files or directories respectively. 
%                 If omitted, both files and directories are included in the 
%                 search results.
%
% Outputs:
% 
%   hits    - Cell array of strings containing the files/directories that
%             have a name which contains the pattern.
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
  error(nargchk(2, 3, nargin));
  
  if nargin == 2, restriction = 'both'; end

  hits = {};
  
  if ~isdir(root),     return; end
  if isempty(pattern), return; end
  
  % case when the pattern is already a full path with filename
  if exist(pattern, 'file') == 2
      hits{end+1} = pattern;
      return;
  end
  
  entries = dir(root);
  
  for k = 3:length(entries) % we ignore . and ..
    
    d = entries(k);
    
    % compare file and directory names against pattern. doing 
    % string comparisons here is inefficient; better way would 
    % be to convert to a number and do numerical comparison; 
    % this would also require fsearch to accept the restriction 
    % input as a numerical (because of the recursive call below)
    switch lower(restriction)
        case 'dirs'
            if ~d.isdir, continue; end
            if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                hits{end+1} = fullfile(root, d.name);
            end
        case 'files'
            if d.isdir
                % recursively search subdirectories
                subhits = fsearch(pattern, [root filesep d.name], restriction);
                hits = [hits subhits];
            else
                if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                    hits{end+1} = fullfile(root, d.name);
                end
            end
        otherwise % both
            if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                hits{end+1} = fullfile(root, d.name);
            end
            
            if d.isdir
                % recursively search subdirectories
                subhits = fsearch(pattern, fullfile(root, d.name), restriction);
                hits = [hits subhits];
            end
    end
  end
end
