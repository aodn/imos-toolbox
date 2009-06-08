function graphs = listGraphs()
%LISTGRAPHS Returns a cell array containing the names of all available
%graphing functions.
%
% Graph functions live in the Graph subdirectory, and are named according
% to the format:
%
%   graph[GraphType].m
%
% This function simply searches the subdirectory looking for files which
% match the above pattern, and returns the names of those files, minus the 
% 'graph' prefix, and the '.m' suffix.
%
% Outputs:
%   graphs - cell array of strings, each of which is the name of a graph
%            function. The caller must add the 'graph' prefix before
%            converting the name into a callable function.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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

graphs = {};

% get the location of the Graph directory
path = fileparts(which(mfilename));

% get the contents of the Graph directory
files = dir(path);

%iterate through each element in the Graph directory
for file = files'

  %skip subdirectories
  if file.isdir == 1, continue; end

  %if name is of the pattern "graph*.m", add 
  %it to the list of available graphs
  token = regexp(file.name, '^graph(.+)\.m$', 'tokens');

  %add the graph name to the list
  if ~isempty(token), graphs{end + 1} = token{1}{1}; end

end
