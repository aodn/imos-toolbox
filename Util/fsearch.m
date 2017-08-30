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
  
  % case when the pattern is already a full path with filename
  if exist(pattern, 'file') == 2
      hits{end+1} = pattern;
      return;
  end
  
  entries = dir(root);
  
  for k = 1:length(entries)
    
    d = entries(k);
    
    % we ignore . and ..
    if any(strcmpi(d.name, {'.', '..'})), continue; end
    
    % compare file and directory names against pattern. doing 
    % string comparisons here is inefficient; better way would 
    % be to convert to a number and do numerical comparison; 
    % this would also require fsearch to accept the restriction 
    % input as a numerical (because of the recursive call below)
    switch lower(restriction)
        case 'dirs'
            if ~d.isdir, continue; end
            if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                % we check that the radical name is the one we're
                % looking for. We want 4T3993 to match path/4T3993/ but not
                % path/454T3993
                [~, foundName, foundExt] = fileparts(d.name);
                [~, patternName, patternExt] = fileparts(pattern);
                if strcmpi(foundName, patternName)
                    hits{end+1} = fullfile(root, d.name);
                end
            end
        case 'files'
            if d.isdir
                % recursively search subdirectories
                subhits = fsearch(pattern, [root filesep d.name], restriction);
                hits = [hits subhits];
            else
                if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                    % we check that the radical name is the one we're
                    % looking for. We want 4T3993 to match 4T3993.DAT or
                    % 4T3993.csv but not 454T3993.DAT
                    [~, foundName, foundExt] = fileparts(d.name);
                    [~, patternName, patternExt] = fileparts(pattern);
                    if strcmpi(foundName, patternName)
                        hits{end+1} = fullfile(root, d.name);
                    end
                end
            end
        otherwise % both
            if ~isempty(strfind(lower(fullfile(root, d.name)), lower(pattern)))
                % we check that the radical name is the one we're
                % looking for. We want 4T3993 to match path/4T3993/ or
                % path/4T3993.DAT but not path/454T3993 nor
                % path/454T3993.DAT
                [~, foundName, foundExt] = fileparts(d.name);
                [~, patternName, patternExt] = fileparts(pattern);
                if strcmpi(foundName, patternName)
                    hits{end+1} = fullfile(root, d.name);
                end
            end
            
            if d.isdir
                % recursively search subdirectories
                subhits = fsearch(pattern, fullfile(root, d.name), restriction);
                hits = [hits subhits];
            end
    end
  end
end
