function [data, flags, log] = rangeQC ( sample_data, cal_data, data, k )
%RANGEQC Flags data which is out of the parameter's valid range.
%
% Iterates through the given data, and returns flags for any samples which
% do not fall within the max_value and min_value fields in the given cal_data 
% struct.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   cal_data    - struct which contains the max_value and min_value fields for 
%                 each parameter, and the qc_set in use.
%
%   data        - the vector of data to check.
%
%   k           - Index into the cal_data/sample_data.parameters vectors.
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data which is out of range.
%
%   log         - Empty cell array.
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

error(nargchk(4, 4, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isstruct(cal_data),           error('cal_data must be a struct');    end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end

log = {};

% get the flag values with which we flag good and out of range data
rangeFlag = imosQCFlag('bound', cal_data.qc_set);
goodFlag  = imosQCFlag('good',  cal_data.qc_set);

% initialise all flags to good
flags    = zeros(length(data),1);
flags(:) = goodFlag;

max  = cal_data.parameters(k).max_value;
min  = cal_data.parameters(k).min_value;

% add flags for out of range values
flags(data > max) = rangeFlag;
flags(data < min) = rangeFlag;
