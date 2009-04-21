function sample_data = rangeQC ( sample_data, cal_data )
%RANGEQC Flags data which is out of the parameter's valid range.
%
% Iterates through the given data set, and adds flags for any samples which
% do not fall within the max_value and min_value fields in the given cal_data 
% struct; this is done for each parameter.
%
% Inputs:
%   sample_data - struct containing a vector of parameter structs, which in
%                 turn contain the data.
%
%   cal_data    - struct which contains the max_value and min_value fields for 
%                 each parameter, and the qc_set in use.
%
% Outputs:
%   sample_data - same as input, with flags added for out of range data.
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

error(nargchk(2, 2, nargin));
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isstruct(cal_data),    error('cal_data must be a struct');    end

% get the flag value with which we flag out of range data
flag = imosQCFlag('bound', cal_data.qc_set);

% iterate through each paramter in the data set
for k = 1:length(sample_data.parameters)
  
  data = sample_data.parameters(k).data;
  max  = cal_data.parameters(k).max_value;
  min  = cal_data.parameters(k).min_value;
  
  % add flags for out of range values
  sample_data.parameters(k).flags(data > max) = flag;
  sample_data.parameters(k).flags(data < min) = flag;
  
end
