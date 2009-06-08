function flags = flagTimeSeries( parent, graphs, sample_data, vars, dimension )
%flagTimeSeries Overlays flags for the given sample data variables on the
% given graphs
%
% Inputs:
%   parent      - handle to parent figure/uipanel.
%   graphs      - vector handles to axis objects (one for each variable).
%   sample_data - struct containing the sample data.
%   vars        - vector of indices into the sample_data.variables array.
%                 Must be the same length as graphs.
%   dimension   - Index into the sample_data.dimensions array, to the
%                 current dimension.
%
% Outputs:
%   flag        - handles to line objects that make up the flag overlays.
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

error(nargchk(5,5,nargin));

if ~ishandle(parent),      error('parent must be a graphic handle');    end
if ~ishandle(graphs),      error('graphs must be a graphic handle(s)'); end
if ~isstruct(sample_data), error('sample_data must be a struct');       end
if ~isvector(vars),        error('vars must be a vector of indices');   end
if ~isnumeric(dimension),  error('dimension must be an index');         end

sample_data.variables = sample_data.variables(vars);
if length(graphs) ~= length(sample_data.variables)
  error('graphs must be the same length as vars');
end
  
qcSet = str2double(readToolboxProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

flags = [];

hold on;

for k = 1:length(sample_data.variables)

  dim   = sample_data.dimensions{dimension}.data;
  fl    = sample_data.variables{k}.flags;
  data  = sample_data.variables{k}.data;

  % get a list of the different flag types to be graphed
  flagTypes = unique(fl);

  % if no flags to plot, put a dummy handle in - the 
  % caller is responsible for checking and ignoring
  flags(k,:) = 0.0;

  % a different line for each flag type
  for m = 1:length(flagTypes)

    % don't display raw data flags
    if flagTypes(m) == rawFlag, continue; end

    f = find(fl == flagTypes(m));

    fc = imosQCFlag(flagTypes(m), qcSet, 'color');

    fx = dim(f);
    fy = data(f);

    flags(k,m) = line(fx, fy,...
      'Parent', graphs(k),...
      'LineStyle', 'none',...
      'Marker', 'o',...
      'MarkerFaceColor', fc,...
      'MarkerEdgeColor', 'none');
  end
end
