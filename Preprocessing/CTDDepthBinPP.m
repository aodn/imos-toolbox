function sample_data = CTDDepthBinPP( sample_data, qcLevel, auto )
%CTDDepthBinPP( sample_data, auto)
%
% Bins vertical depths
%
% Inputs:
%   sample_data - cell array of data sets, ideally with depth variable.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
%   From CTDPresBinPP.txt:
%           Bin Size:    Bin Size for vertical binning (default 1m)
%
% Outputs:
%   sample_data - variables vertically binned to pressure levels
%
% Author:       Charles James (charles.james@sa.gov.au)
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
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% read options from parameter file  Minimum Soak Delay: SoakDelay1 (sec.)
%                                   Optimal Soak Delay: SoakDelay2 (sec.)
PressFile = ['Preprocessing' filesep 'CTDDepthBinPP.txt'];
bin_size = str2double(readProperty('bin_size', PressFile));

firstbin = -bin_size/2;
ctdSSflags = {'tempSoakStatus', 'cndSoakStatus', 'oxSoakStatus'};

for k=1:length(sample_data) % going through different casts
    
    curSam = sample_data{k};    
    iDepth  = getVar(curSam.dimensions, 'DEPTH');
    iSBE    = getVar(curSam.variables, 'SBE_FLAG');
    if iDepth ~= 0
       depth = curSam.dimensions{iDepth}.data;
       lastbin = round(max(depth)) + bin_size/2;
       
       if iSBE ~= 0
           ibad = isnan(curSam.variables{iSBE}.data); % any SBE flag 0 is good and NaN is bad.
       else
           ibad = false(size(depth));
       end
       
       zbin = firstbin:bin_size:lastbin;
       
       zstart = zbin(1:end-1);
       zend = zbin(2:end);
       
       z = (zstart + zend)/2; % depth of the actual centre of each bin
       curSam.dimensions{iDepth}.data = z(:);
       
       [Z, ZSTART] = meshgrid(depth, zstart);
       [~, ZEND] = meshgrid(depth, zend);
       IND = (Z >= ZSTART) & (Z < ZEND);
       
       FLAGS = meshgrid(curSam.dimensions{iDepth}.flags, z);
       curSam.dimensions{iDepth}.flags = max(FLAGS.*int8(IND), [], 2);
       
       for ivar=1:length(curSam.variables); % going through different measured parameters
           
           curVar = curSam.variables{ivar};
           depthdim = (curVar.dimensions == iDepth);
           if any(depthdim)
                data = curVar.data;
                flags = curVar.flags;
                IVAR = IND;
                
                % remove bad SBE data from bins
                IBAD = meshgrid(ibad, zstart);
                IVAR(IBAD) = false; % any bad data in bin is not taken into account
                DATA = meshgrid(data, zstart);
                FLAGS = meshgrid(flags, zstart);
                binFLAGS = max(FLAGS.*int8(IND), [], 2);
                curVar.flags = binFLAGS;
                
                if ~ismember(curVar.name, ctdSSflags)
                    % binning data values
                    DATA(~IVAR) = 0; % set bad data value to 0 not to take it into account during averaging
                    binDATA = sum(DATA, 2)./sum(IVAR, 2); % mean value for each bin
                else
                    % binning CTD soak status values
                    % use highest (worst) status value
                    binDATA = max(int8(DATA).*int8(IND), [], 2);
                end
                curVar.data = binDATA;
                
                % redefine current parameter
                curSam.variables{ivar} = curVar;
           end
       end
       
       % redefine current ctd cast
       sample_data{k} = curSam;
       
       CTDDepthBinComment = ['CTDDepthBinPP: Every variable function of DEPTH has been vertically binned with a bin size of ' num2str(bin_size) 'm.'];
       
       history = sample_data{k}.history;
       if isempty(history)
           sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), CTDDepthBinComment);
       else
           sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), CTDDepthBinComment);
       end
    end
end


end
