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