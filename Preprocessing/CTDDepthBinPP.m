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
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% in order to achieve consistency across facilities (which for the most part except SA already use binned
% datasets) and with FV01 files, this PP routine is performed on the raw FV00 dataset

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
       
       curSam.dimensions{iDepth}.data = z(:); % update dimension and global attribute values
       curSam.geospatial_vertical_min = min(z(:));
       curSam.geospatial_vertical_max = max(z(:));
       
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
