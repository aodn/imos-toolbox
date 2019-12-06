function [data, flags, paramsLog] = imosRegionalRangeQC ( sample_data, data, k, type, auto )
%IMOSREGIONALRANGEQC Flags data which is out of the variable's valid regional range.
%
% Iterates through the given data, and returns flags for any samples which
% do not fall within the regionalRangeMin and regionalRangeMax fields for the given
% mooring site and variable in imosRegionalRangeQC.txt.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector/matrix of data to check.
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
%                 data which is out of range.
%
%   paramsLog   - string containing details about params' procedure to include in QC log
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

narginchk(4, 5);
if ~isstruct(sample_data),              error('sample_data must be a struct');      end
if ~isscalar(k) || ~isnumeric(k),       error('k must be a numeric scalar');        end
if ~ischar(type),                       error('type must be a string');             end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];

if ~strcmp(type, 'variables'), return; end

% let's handle the case we have multiple same param distinguished by "_1",
% "_2", etc...
paramName = sample_data.(type){k}.name;
iLastUnderscore = strfind(paramName, '_');
if iLastUnderscore > 0
    iLastUnderscore = iLastUnderscore(end);
    if length(paramName) > iLastUnderscore
        if ~isnan(str2double(paramName(iLastUnderscore+1:end)))
            paramName = paramName(1:iLastUnderscore-1);
        end
    end
end

% get details from this site
%     site = sample_data.meta.site_name; % source = ddb
%     if strcmpi(site, 'UNKNOWN'), site = sample_data.site_code; end % source = global_attributes file
site = sample_data.site_code;

% test if site information exists
if isempty(site)
    fprintf('%s\n', ['Warning : ' 'No site information found to '...
        'perform regional range QC test']);
else
    % for test in display
    sampleFile = sample_data.toolbox_input_file;
    
    mWh = findobj('Tag', 'mainWindow');
    climatologyRange = get(mWh, 'UserData');
    p = 0;
    if isempty(climatologyRange)
        p = 1;
        climatologyRange(p).dataSet = sampleFile;
        climatologyRange(p).(['rangeMin' paramName]) = nan(2, 1);
        climatologyRange(p).(['rangeMax' paramName]) = nan(2, 1);
    else
        for i=1:length(climatologyRange)
            if strcmp(climatologyRange(i).dataSet, sampleFile)
                p=i;
                break;
            end
        end
        if p == 0
            p = length(climatologyRange) + 1;
            climatologyRange(p).dataSet = sampleFile;
            climatologyRange(p).(['rangeMin' paramName]) = nan(2, 1);
            climatologyRange(p).(['rangeMax' paramName]) = nan(2, 1);
        end
    end
    
    % read values from imosRegionalRangeQC properties file
    [regionalMin, regionalMax, isSite] = getImosRegionalRange(site, paramName);
    
    if ~isSite
        fprintf('%s\n', ['Warning : ' 'File imosRegionalRangeQC.txt is not documented '...
        'for site ' site]);
    else
        if ~isnan(regionalMin)
            % get the flag values with which we flag good and out of range data
            qcSet     = str2double(readProperty('toolbox.qc_set'));
            rangeFlag = imosQCFlag('bad', qcSet, 'flag');
            rawFlag   = imosQCFlag('raw',   qcSet, 'flag');
            goodFlag  = imosQCFlag('good',  qcSet, 'flag');
            
            % matrix case, we unfold the matrix in one vector for timeserie study
            % purpose
            isMatrix = size(data, 1)>1 & size(data, 2)>1;
            if isMatrix
                len1 = size(data, 1);
                len2 = size(data, 2);
                len3 = size(data, 3);
                data = data(:);
            end
            lenData = length(data);
            
            % initialise all flags to non QC'd
            flags = ones(lenData, 1, 'int8')*rawFlag;
            
            if regionalMax ~= regionalMin % otherwise test is ignored
                paramsLog = ['min=' num2str(regionalMin) ', max=' num2str(regionalMax)];
                
                % initialise all flags to bad
                flags = ones(lenData, 1, 'int8')*rangeFlag;
                
                iPassed = data <= regionalMax;
                iPassed = iPassed & data >= regionalMin;
                
                % add flags for in range values
                flags(iPassed) = goodFlag;
                flags(iPassed) = goodFlag;
            end
            
            if isMatrix
                % we fold the vector back into a matrix
                data = reshape(data, [len1, len2, len3]);
                flags = reshape(flags, [len1, len2, len3]);
            end
            
            % update climatologyRange info for display
            climatologyRange(p).(['rangeMin' paramName]) = ones(2, 1)*regionalMin;
            climatologyRange(p).(['rangeMax' paramName]) = ones(2, 1)*regionalMax;
            set(mWh, 'UserData', climatologyRange);
        end
    end
end

end

function [regionalRangeMin, regionalRangeMax, isSite] = getImosRegionalRange(siteName, paramName)
%GETIMOSREGIONALRANGE Returns the regionalRangeMin, regionalRangeMax thresholds 
% to QC data with the regional range QC test. 
%
% These thresholds values were taken from an histogram distribution
% analysis either from historical water samples or in-situ sensor data. If
% no threshold value is found then NaN is returned.
%
% Inputs:
%   siteName  - siteName of the required site. 
%   paramName - paramName of the required IMOS parameter. 
%
% Outputs:
%   regionalRangeMin - lower threshold value for the regional range test
%   regionalRangeMax - upper threshold value for the regional range test
%   isSite           - boolean true if site is found in the list
%

narginchk(2, 2);
if ~ischar(siteName),    error('siteName must be a string'); end
if ~ischar(paramName),   error('paramName must be a string'); end

regionalRangeMin = NaN;
regionalRangeMax = NaN;
isSite = false;

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'AutomaticQC');

fid = -1;
regRange = [];
try
  fid = fopen([path filesep 'imosRegionalRangeQC.txt'], 'rt');
  if fid == -1, return; end
  
  regRange = textscan(fid, '%s%s%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% look for a site and parameter match
iSite  = strcmpi(siteName,  regRange{1});
iParam = strcmpi(paramName, regRange{2});
iLine = iSite & iParam;

if any(iSite), isSite = true; end

if any(iLine)
    regionalRangeMin = regRange{3}(iLine);
    regionalRangeMax = regRange{4}(iLine);
end
end