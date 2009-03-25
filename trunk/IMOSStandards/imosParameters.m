function [ standard_name uom ] = imosParameters( short_name )
%IMOSPARAMETERS Returns IMOS compliant standard name and units of measurement
% given the short parameter name.
%
% The list of all IMOS parameters is stored in a file 'imosParameters.txt'
% which is in the same directory as this m-file.
%
% The file imosParameters.txt contains a list of all parameters for which an
% IMOS compliant identifier (the short_name) exists. This function looks up the 
% given short_name and returns the corresponding standard name and units of 
% measurement. If the given short_name is not in the list of IMOS parameters,
% the standard_name is set to the given short_name, and uom is left empty.
%
% Inputs:
%   short_name - the IMOS parameter name
%
% Outputs:
%   standard_name - the IMOS standard name for the parameter
%
%   uom - Units of measurement
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

error(nargchk(1, 1, nargin));
if ~ischar(short_name), error('short_name must be a string'); end

standard_name = short_name;
uom           = '';

% get the location of this m-file, which is 
% also the location of imosParamaters.txt
path = fileparts(which(mfilename));

fid = fopen([path filesep 'imosParameters.txt']);
if fid == -1, return; end

params = textscan(fid, '%s%s%s', 'delimiter', ',', 'commentStyle', '%');

names          = params{1};
standard_names = params{2};
uoms           = params{3};

% search the list for a match
for k = 1:length(names)
  
  if strcmp(short_name, names{k})
    
    standard_name = standard_names{k};
    uom           = uoms{k};
    break;
  end
end
