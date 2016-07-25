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
% The mappings between parameters and graph types is contained in the file
% Graph/[Graph]/parameters.txt, where [Graph] is e.g. 'TimeSeries'.
%
% The different graph 'functions' are:
%   graph        - Function for graphing data. There are two types of 'graph'
%                  functions - the top level function defining the graph type, 
%                  which graphs a set of variables, and the functions which 
%                  graph single variables. The top level functions must be of 
%                  the form:
%                    function [graphs lines] = ...
%                      graphGraph( parent, sample_data, vars )
%                  Graph functions which graph a single variable must be of
%                  the form:
%                    function h = graphGraphType( ax, sample_data, var )
%
%   select       - Function which adds data selection capability to a plot.
%                  Must be of the form:
%                    function selectGraphType( selectCallback, clickCallback )
%
%   highlight    - Function which highlights a region on a plot.
%                  Must be of the form:
%                    function h = highlightGraphType( region, data )
%
%   getSelected  - Function which returns the data indices of currently
%                  highlighted data on a plot. Must be of the form:
%                    function dataIdx = getSelectedGraphType ()
%
%   flag         - Function which overlays QC flags on a plot. Must be of the
%                  form:
%                    function flags = flagGraphType( ...
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
narginchk(3,3);

if ~ischar(graphType), error('graphType must be a string'); end
if ~ischar(graphFunc), error('graphFunc must be a string'); end
if ~ischar(var),       error('var must be a string');       end

% account for numbered parameters (if the dataset 
% contains more than one variable of the same name)
match = regexp(var, '_\d$');
if ~isempty(match), var(match:end) = ''; end

% get path to graph directory (e.g. 'Graph')
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
graphDir = fullfile(path, 'Graph');

% check that the directory exists
if isempty(dir(graphDir))
  error(['invalid graph type: ' graphDir]); 
end

% top level graph functions are in the Graph subdirectory
if strcmp(graphFunc, 'graph') && isempty(var)
  funcFile = [graphDir filesep 'graph' graphType '.m'];

% top level flag functions are in the Graph subdirectory
elseif strcmp(graphFunc, 'flag') && isempty(var)
  funcFile = [graphDir filesep 'flag' graphType '.m'];
  
% other functions are in the Graph/graphType subdirectory
else
  
  % get path to graph type subdirectory (e.g. 'Graph/TimeSeries')
  graphDir = [graphDir filesep graphType];
  
  % read in parameter mapping
  fid = -1;
  parameters = {};
  try
    fid = fopen([graphDir filesep 'parameters.txt']);
    if fid == -1
      error(['could not open ' graphDir filesep 'parameters.txt']); 
    end
    parameters = textscan(fid, '%s%s', 'CommentStyle', '%', 'Delimiter', ',');
    parameters = deblank(parameters);
    fclose(fid);
  catch e
    if fid ~= -1, fclose(fid); end
    parameters = {{}, {}};
  end

  % find the graph type for the specified parameter; 
  % if not in the list, use generic graph type
  idx = find(ismember(parameters{1}, var));
  if ~isempty(idx), var = parameters{2}{idx};
  else              var = 'Generic';
  end
  
  % try to find the requested function
  funcFile = [graphDir filesep graphFunc graphType var '.m'];
  
  % revert to generic implementation
  if isempty(dir(funcFile)),
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
