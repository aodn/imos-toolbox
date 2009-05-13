function sample_data = makeNetCDFCompliant( sample_data )
%MAKENETCDFCOMPLIANT Adds/modifies fields in the given sample_data struct
% to make it compliant with the IMOS NetCDF standard.
%
% Uses the template files contained in the NetCDF/templates subdirectory to
% add/modify fields in the given sample_data struct to make it compliant
% with the IMOS NetCDF standard. See the parseNetCDFTemplate function for
% more details on the template files.
%
% Inputs:
%   sample_data - a struct containing sample data.
%
% Outputs:
%   sample_data - same as input, with fields added/modified based on the
%   NeteCDF template files.
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
  error(nargchk(1,1,nargin));

  if ~isstruct(sample_data), error('sample_data must be a struct'); end

  %
  % global attributes
  %

  % get path to templates subdirectory
  path = [fileparts(which(mfilename)) filesep 'template' filesep];

  globAtts = parseNetCDFTemplate([path 'global_attributes.txt'], sample_data);

  % merge global atts into sample_data
  sample_data = mergeAtts(sample_data, globAtts);

  %
  % coordinate variables
  %
  
  for k = 1:length(sample_data.dimensions)

    dim = sample_data.dimensions(k);
    
    temp = [path lower(dim.name) '_attributes.txt'];

    dimAtts = parseNetCDFTemplate(temp, sample_data);

    % merge dimension atts back into dimension struct
    sample_data.dimensions = mergeAtts(sample_data.dimensions, dimAtts, k);
  end

  %
  % variables
  %
  
  for k = 1:length(sample_data.variables)
    
    temp = [path 'variable_attributes.txt'];

    varAtts = parseNetCDFTemplate(temp, sample_data);

    % merge variable atts back into variable struct
    sample_data.variables = mergeAtts(sample_data.variables, varAtts, k);
  end
end

function target = mergeAtts ( target, atts, k )
%MERGEATTS copies the fields in the given atts struct into the given target
%struct. If k is provided, it is used as an index into targets.
%
  if nargin == 2, k = 1; end

  fields = fieldnames(atts);
  
  for m = 1:length(fields)
    
    target(k).(fields{m}) = atts.(fields{m});
  end
end
