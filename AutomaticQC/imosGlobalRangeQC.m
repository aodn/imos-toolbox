function [data, flags, paramsLog] = imosGlobalRangeQC ( sample_data, data, k, type, auto )
%IMOSGLOBALRANGEQC Flags data which is out of the variable's valid global range.
%
% Iterates through the given data, and returns flags for any samples which
% do not fall within the valid_min and valid_max fields for the given
% variable.
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
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

% read all values from imosGlobalRangeQC properties file
values = readProperty('*', fullfile('AutomaticQC', 'imosGlobalRangeQC.txt'));
param = strtrim(values{1});

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

iParam = strcmpi(paramName, param);

if any(iParam)
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
    
    % get the flag values with which we flag good and out of range data
    qcSet     = str2double(readProperty('toolbox.qc_set'));
    rangeFlag = imosQCFlag('bad', qcSet, 'flag');
    rawFlag   = imosQCFlag('raw',   qcSet, 'flag');
    goodFlag  = imosQCFlag('good',  qcSet, 'flag');
    
    max  = sample_data.variables{k}.valid_max;
    min  = sample_data.variables{k}.valid_min;
    
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
    
    if ~isempty(min) && ~isempty(max)
        if max ~= min
            paramsLog = ['min=' num2str(min) ', max=' num2str(max)];
            
            % initialise all flags to bad
            flags = ones(lenData, 1, 'int8')*rangeFlag;
            
            iPassed = data <= max;
            iPassed = iPassed & data >= min;
            
            % add flags for in range values
            flags(iPassed) = goodFlag;
            flags(iPassed) = goodFlag;
            
            % update climatologyRange info for display
            climatologyRange(p).(['rangeMin' paramName]) = ones(2, 1)*min;
            climatologyRange(p).(['rangeMax' paramName]) = ones(2, 1)*max;
            set(mWh, 'UserData', climatologyRange);
        end
    end
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, [len1, len2, len3]);
        flags = reshape(flags, [len1, len2, len3]);
    end
end
