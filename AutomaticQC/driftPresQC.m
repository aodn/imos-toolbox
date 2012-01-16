function [data flags log] = driftPresQC( sample_data, data, k, type, auto )
%
% This function calculates the median value for sequential blocks of the 
% data set. The median of the first block is taken as the reference,
% each subsequent block median is compared with the reference and the data 
% is flagged if there is an appreciable difference.
% 
%
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags for corresponding
%                 data which has been detected as spiked.
%
%   log         - Empty cell array.
%
% Author:       Mark Snell <mark.snell@csiro.au>
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

error(nargchk(4, 5, nargin));
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end
if ~ischar(type),                 error('type must be a string');        end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

log   = {};
flags   = [];

if ~strcmp(type, 'variables'), return; end

dataName  = sample_data.(type){k}.name;
iVar = 0;
if strcmpi(dataName, 'PRES')
    iVar = 1;
elseif strcmpi(dataName, 'PRES_REL')
    iVar = 2;
elseif strcmpi(dataName, 'DEPTH')
    iVar = 3;
end
    
if iVar > 0
    qcSet     = str2double(readProperty('toolbox.qc_set'));
    goodFlag  = imosQCFlag('good',  qcSet, 'flag');
    driftFlag = imosQCFlag('bad', qcSet, 'flag');
    
    lenData = length(data);
    flags = ones(lenData, 1)*goodFlag;
    
    nblocks = str2double(...
        readProperty('nblocks', fullfile('AutomaticQC', 'driftPresQC.txt')));
    drifterror = str2double(...
        readProperty('drifterror', fullfile('AutomaticQC', 'driftPresQC.txt')));
    
    % number of points to consider in a block
    blocksize = round(lenData/nblocks);
    
    % reference value is the median on data from the first block,
    % this assumes the first block is good and hasn't already drifted too much.
    % How about the time spent in deploying the instrument???
    % How about strong current events which will lay down the mooring???
    ref = median(data(1:blocksize));
    
    % let's study other blocks
    for n=1:nblocks-2
        blockstart  = n*blocksize + 1;
        blockend    = blockstart + blocksize;
        x           = median( data(blockstart:blockend) );
        
        if( abs(x-ref) > drifterror )
            flags(blockstart:blockend) = driftFlag;
        end
    end
    
    %last block
    blockstart = (nblocks-1)*blocksize+1;
    x = median( data(blockstart:end) );
    
    if( abs(x-ref) > drifterror )
        flags(blockstart:end) = driftFlag;
    end
end