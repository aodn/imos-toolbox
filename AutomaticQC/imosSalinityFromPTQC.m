function [data, flags, paramsLog] = imosSalinityFromPTQC ( sample_data, data, k, type, auto )
%IMOSSALINITYFROMPTQC Flags salinity data which is flagged in pressure/depth, conductivity
% and temperature.
%
% Looks for highest flags from pressure/depth, conductivity and temperature variables and give
% them to salinity
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

salinityName = {'PSAL'};

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

iParam = strcmpi(paramName, salinityName);

if any(iParam)
    % get the flag values with which we flag good and out of range data
    qcSet     = str2double(readProperty('toolbox.qc_set'));
    rawFlag   = imosQCFlag('raw',   qcSet, 'flag');
    
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
    depthFlags = ones(lenData, 1, 'int8')*rawFlag;
    pressureFlags = ones(lenData, 1, 'int8')*rawFlag;
    
    % we look for flags from pressure, conductivity and temperature data to give them
    % to salinity as well
    paramNames = {'TEMP', 'CNDC'};
    depthName = {'DEPTH'};
    pressureNames = {'PRES_REL', 'PRES'};
    
    isDepth = false;
    for i=1:length(sample_data.(type))
        % let's handle the case we have multiple same param distinguished by "_1",
        % "_2", etc...
        paramName = sample_data.(type){i}.name;
        iLastUnderscore = strfind(paramName, '_');
        if iLastUnderscore > 0
            iLastUnderscore = iLastUnderscore(end);
            if length(paramName) > iLastUnderscore
                if ~isnan(str2double(paramName(iLastUnderscore+1:end)))
                    paramName = paramName(1:iLastUnderscore-1);
                end
            end
        end

        if any(strcmpi(paramName, paramNames))
            flags = max(flags, sample_data.(type){i}.flags(:));
        end

        if any(strcmpi(paramName, pressureNames))
            pressureFlags = max(pressureFlags, sample_data.(type){i}.flags(:));
        end
        
        if any(strcmpi(paramName, depthName))
            isDepth = true;
            depthFlags = max(depthFlags, sample_data.(type){i}.flags(:));
        end
    end
    
    % in case DEPTH has been inferred from a neighbouring sensor when PRES
    % or PRES_REL failed, we only consider DEPTH flags
    if isDepth
        flags = max(flags, depthFlags);
    else
        flags = max(flags, pressureFlags);
    end
    
    
    if isMatrix
        % we fold the vector back into a matrix
        data = reshape(data, [len1, len2, len3]);
        flags = reshape(flags, [len1, len2, len3]);
    end
end
