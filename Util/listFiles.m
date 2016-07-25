function hits = listFiles(path, pattern)
%LISTFILES Returns a cell array containing the names of all files in the
% given directory which match the given (regex) pattern.
%
% This function simply searches the given directory looking for files which
% match the given pattern, and returns the names of those files.
%
% Inputs:
%   path    - Name of the directory in which to search. 
%   pattern - Regular expression pattern to match against.
%
% Outputs:
%   hits    - cell array of strings, each of which is the name of a file 
%             in the given directory which matched the given pattern.
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
narginchk(2,2);

if ~ischar(path),    error('path must be a string');    end
if ~ischar(pattern), error('pattern must be a string'); end

hits = {};

% get the contents of the directory
files = dir(path);

%iterate through each element in the directory
for file = files'

  %skip subdirectories
  if file.isdir == 1, continue; end

  %if name matches the pattern, add 
  %it to the list of hits
  token = regexp(file.name, pattern, 'tokens');

  %add the name name to the list
  if ~isempty(token), hits{end + 1} = token{1}{1}; end

end

% sort alphabetical, case insensitive
[ignore idx] = sort(lower(hits));
hits         = hits(idx);
