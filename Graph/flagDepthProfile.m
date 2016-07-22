function flags = flagDepthProfile( parent, graphs, sample_data, vars )
%FLAGDEPTHPROFILE Overlays flags for the given sample data variables on the 
% given depth profile graphs.
%
% Inputs:
%   parent      - handle to parent figure/uipanel.
%   graphs      - vector handles to axis objects (one for each variable).
%   sample_data - struct containing the sample data.
%   vars        - vector of indices into the sample_data.variables array.
%                 Must be the same length as graphs.
%
% Outputs:
%   flag        - handles to line objects that make up the flag overlays.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

narginchk(4,4);

if ~ishandle(parent),      error('parent must be a graphic handle');    end
if ~ishandle(graphs),      error('graphs must be a graphic handle(s)'); end
if ~isstruct(sample_data), error('sample_data must be a struct');       end
if ~isnumeric(vars),       error('vars must be a numeric');             end

flags = [];

if isempty(vars), return; end

% make sure the data set contains depth
% data, either a dimension or a variable
depth = getVar(sample_data.variables, 'DEPTH');

if depth == 0
    depth = getVar(sample_data.dimensions, 'DEPTH');
    
    if depth == 0, error('data set contains no depth data'); end
end

vars(vars == depth) = [];
if isempty(vars), return; end

hold on;

for k = 1:length(vars)
  
  % apply the flag function for this variable
  flagFunc = ...
    getGraphFunc('DepthProfile', 'flag', sample_data.variables{vars(k)}.name);
  f = flagFunc(graphs(k), sample_data, vars(k));
  
  % if the flag function returned nothing, insert a dummy handle 
  if isempty(f), f = 0.0; end
  
  %
  % the following is some ugly code which takes the flag handle(s) returned
  % from the variable-specific flag function, and saves it/them in the 
  % flags matrix, accounting for differences in size.
  %
  
  fl = length(f);
  fs = size(flags,2);
  
  if     fl > fs, flags(:,fs+1:fl) = 0.0;
  elseif fl < fs, f    (  fl+1:fs) = 0.0;
  end
  
  flags(k,:) = f;
end
