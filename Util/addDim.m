function sam = addDim(sam, name, data, comment)
%ADDDIM Adds a new dimension to the given data set.
%
% Adds a new variable with the given name, data and commment to
% the given data set.
%
% Inputs:
%   sam        - data set to which the new dimension is added
%   name       - new dimension name
%   data       - dimension data
%   comment    - dimension comment
%
% Outputs:
%   sam        - data set  with the new dimension added.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(4, 4);

if ~isstruct( sam),        error('sam must be a struct');        end
if ~ischar(   name),       error('name must be a string');       end
if ~isnumeric(data),       error('data must be a matrix');       end
if ~ischar(   comment),    error('comment must be a string');    end

qcSet   = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');

% add new dimension to data set
sam.dimensions{end+1}.name           = name;
sam.dimensions{end  }.typeCastFunc   = str2func(netcdf3ToMatlabType(imosParameters(sam.dimensions{end}.name, 'type')));
sam.dimensions{end  }.data           = sam.dimensions{end}.typeCastFunc(data);
clear data;

% create an empty flags matrix for the new dimension
sam.dimensions{end}.flags(1:numel(sam.dimensions{end}.data)) = rawFlag;
sam.dimensions{end}.flags = reshape(...
  sam.dimensions{end}.flags, size(sam.dimensions{end}.data));
  
% ensure that the new dimension is populated  with all 
% required NetCDF  attributes - all existing fields are 
% left unmodified by the makeNetCDFCompliant function
sam = makeNetCDFCompliant(sam);

if isfield(sam.dimensions{end}, 'comment')
    sam.dimensions{end}.comment      = comment;
end
  