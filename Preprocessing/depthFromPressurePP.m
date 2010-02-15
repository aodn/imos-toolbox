function sample_data = depthFromPressurePP( sample_data )
%depthFromPressurePP Adds a depth variable to the given data sets, if they
% contains a pressure variable.
%
% This function uses the CSIRO Matlab Seawater Library to derive depth data 
% from pressure. It adds the depth data as a new variable in the data sets.
% Data sets which do not contain a pressure variable are left unmodified.
%
% This function uses a latitude of -30.0 degrees. A future easy enhancement
% would be to prompt the user to enter a latitude, but different latitude 
% values don't make much of a difference to the result (a variation of around 
% 6 metres for depths of ~ 1000 metres).
%
% Inputs:
%   sample_data - cell array of data sets, ideally with pressure variables.
%
% Outputs:
%   sample_data - the same data sets, with depth variables added.
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
error(nargchk(nargin, 1, 1));

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

qcSet   = str2double(readProperty('toolbox.qc_set'));
rawFlag = imosQCFlag('raw', qcSet, 'flag');
  
for k = 1:length(sample_data)
  
  sam = sample_data{k};

  presIdx = getVar(sam.variables, 'PRES');

  % no pressure data
  if ~presIdx, continue; end

  depth = sw_dpth(sam.variables{presIdx}.data, -30.0);

  % create basic variable data
  sam.variables{end+1}.name       = 'DEPTH';
  sam.variables{end}  .dimensions = sam.variables{presIdx}.dimensions;
  sam.variables{end}  .data       = depth;
  sam.variables{end}  .comment    = 'depthFromPressurePP: derived from PRES';
  
  % create an empty flags matrix for the new variable
  sam.variables{end}.flags(1:numel(sam.variables{end}.data)) = rawFlag;
  sam.variables{end}.flags = reshape(...
    sam.variables{end}.flags, size(sam.variables{end}.data));
  
  % ensure that the new variable is populated  with all 
  % required NetCDF  attributes - all existing fields are 
  % left unmodified by the makeNetCDFCompliant function
  sample_data{k} = makeNetCDFCompliant(sam);
end
