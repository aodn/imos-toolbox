function func = getGraphFunc( graphType, graphFunc, var )
%GETGRAPHFUNC Returns a function handle for the given graph type, graph
% function, and variable.
%
% Returns a function handle for the given graph type/function and variable.
% The graph type specifies which graph, e.g. 'TimeSeries'. The function is
% one of 'graph', 'select', 'highlight', 'getSelected' or 'flag'. 
% The variable is an IMOS compliant parameter name, e.g. 'TEMP', 'CSPD', or 
% empty if one of the top level (e.g, 'GraphTimeSeries') functions is needed.
%
% The different graph 'functions' are:
%   graph        - Function for graphing data. There are two types of 'graph'
%                  functions - the top level function defining the graph type, 
%                  which graphs a set of variables, and the functions which 
%                  graph single variables. The top level functions must be of 
%                  the form:
%                    function [graphs lines] = ...
%                      graphGraphType( parent, sample_data, vars )
%                  Graph functions which graph a single variable must be of
%                  the form:
%                    function h = ...
%                      graphGraphTypeParameter( ax, sample_data, var )
%
%   select       - Function which adds data selection capability to a plot.
%                  Must be of the form:
%                    function selectGraphTypeParameter( ...
%                      selectCallback, clickCallback )
%
%   highlight    - Function which highlights a region on a plot.
%                  Must be of the form:
%                    function h = highlightGraphTypeParameter( region, data )
%
%   getSelected  - Function which returns the data indices of currently
%                  highlighted data on a plot. Must be of the form:
%                    function dataIdx = ...
%                      getSelectedGraphTypeParameter (  )
%
%   flag         - Function which overlays QC flags on a plot. Must be of the
%                  form:
%                    function flags = flagGraphTypeParameter( ...
%                      parent, graphs, sample_data, vars )
%
% Inputs:
%   graphType - Type of graph, e.g. 'TimeSeries'. 
%   graphFunc - Function - one of 'graph', 'select', 'highlight', 
%               'getSelected', 'flag'.
%   var       - IMOS compliant parameter name.
%
% Outputs:
%   func      - A function handle.
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
error(nargchk(3,3,nargin));

if ~ischar(graphType), error('graphType must be a string'); end
if ~ischar(graphFunc), error('graphFunc must be a string'); end
if ~ischar(var),       error('var must be a string');       end

% get path to graph type subdirectory 
% (e.g. 'Graph/TimeSeries')
graphDir = fileparts(which(mfilename));

% top level graph functions are in the Graph subdirectory
if strcmp(graphFunc, 'graph') && isempty(var)
  funcFile = [graphDir filesep 'graph' graphType '.m'];

% top level flag functions are in the Graph subdirectory
elseif strcmp(graphFunc, 'flag') && isempty(var)
  funcFile = [graphDir filesep 'flag' graphType '.m'];
  
% other functions are in the Graph/graphType subdirectory
else
  graphDir = [graphDir filesep graphType];

  % check that the directory exists
  if isempty(dir(graphDir))
    error(['invalid graph type: ' graphDir]); 
  end

  % try to find the requested function
  funcFile = [graphDir filesep graphFunc graphType var '.m'];
  
  % if the function does not exist, search
  % for a 'generic' alternative
  if isempty(dir(funcFile))
    funcFile = [graphDir filesep graphFunc graphType 'Generic.m'];
  end
end

% if we haven't found a function, throw an error
if isempty(dir(funcFile))
  error(['could not find a suitable function for ' graphFunc ', ' var]);
  
% otherwise return the function handle
else
  [funcFile func] = fileparts(funcFile);
  func = str2func(func);
end
