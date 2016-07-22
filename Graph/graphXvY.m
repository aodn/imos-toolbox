function [graphs lines vars] = graphXvY( parent, sample_data, vars )
%GRAPHTRANSECT Graphs the first two variables from the given data set
% against each other on an X-Y axis.
%
% Inputs:
%   parent             - handle to the parent container.
%   sample_data        - struct containing sample data.
%   vars               - Indices of variables that should be graphed..
%
% Outputs:
%   graphs             - A vector of handles to axes on which the data has 
%                        been graphed.
%   lines              - A matrix of handles to line or surface (or other) 
%                        handles which have been drawn, the same length as 
%                        graphs.
%   vars               - Indices of variables which were graphed.
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
  
  if ~ishandle( parent),       error('parent must be a handle');      end
  if ~isstruct( sample_data),  error('sample_data must be a struct'); end
  if ~isnumeric(vars),         error('vars must be a numeric');       end
  
  graphs = [];
  lines  = [];
    
  if length(vars) < 2
    warning('not enough variables to graph');
    return; 
  end
  
  vars = vars(1:2);
  
  if length(sample_data.variables{vars(1)}.dimensions) > 1 ...
  || length(sample_data.variables{vars(2)}.dimensions) > 1
    error('XvY only supports single dimensional data');
  end
  
  for k = 1:length(vars)
        
    % m points to the other variable
    m = k;
    if m == 1, m = 2;
    else       m = 1;
    end
    
    xname = sample_data.variables{vars(k)}.name;
    yname = sample_data.variables{vars(m)}.name;
    
    xdata = sample_data.variables{vars(k)}.data;
    ydata = sample_data.variables{vars(m)}.data;
    
    % create the axes
    graphs(k) = subplot(1, length(vars), k);
    
    set(graphs(k), 'Parent', parent,...
                   'XGrid',  'on',...
                   'Color', 'none',...
                   'YGrid',  'on', ...
                   'ZGrid',  'on');
    
    lines(k) = line(xdata, ydata);
    
    % set labels
    set(get(graphs(k), 'XLabel'), 'String', xname, 'Interpreter', 'none');
    set(get(graphs(k), 'YLabel'), 'String', yname, 'Interpreter', 'none');
  end
  
  set(lines(1), 'Color', 'blue');
  set(lines(2), 'Color', 'red');
end
