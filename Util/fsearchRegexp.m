function hits = fsearchRegexp(pattern, root, restriction)
%FSEARCH Recursive file/directory search.
%
% Performs a recursive search starting at the given root directory; returns
% the names of all files and directories below the root which have a name
% matching the given regular expression pattern. The name comparison is case 
% insensitive for alphabetical characters.
%
% Inputs:
%
%   pattern     - Pattern to match.
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
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  narginchk(2, 3);

  if nargin == 2, restriction = 'both'; end

  hits = {};
  
  if ~isdir(root),     return; end
  if isempty(pattern), return; end
  
  entries = dir(root);
  
  for k = 1:length(entries)
    
    d = entries(k);
    
    % ignore current/prev entries
    if strcmp(d.name, '.') || strcmp(d.name, '..'), continue; end
    
    % compare file and directory names against pattern. doing 
    % string comparisons here is inefficient; better way would 
    % be to convert to a number and do numerical comparison; 
    % this would also require fsearch to accept the restriction 
    % input as a numerical (because of the recursive call below)
    if strcmp(restriction, 'both')               || ...
      (strcmp(restriction, 'files') && ~d.isdir) ||...
      (strcmp(restriction, 'dirs')  &&  d.isdir)
       
      if ~isempty(regexpi(d.name, pattern))
        hits{end+1} = [root filesep d.name];
      end
    end
    
    % recursively search subdirectories
    if d.isdir, 
      
      subhits = fsearchRegexp(pattern, [root filesep d.name], restriction);
      hits = [hits subhits];
    end
  end
end