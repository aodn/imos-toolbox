function [data, flags, paramsLog] = imosImpossibleDateQC( sample_data, data, k, type, auto )
%IMOSIMPOSSIBLEDATEQC Flags impossible TIME values 
%
% Impossible date test described in Morello et Al. 2011 paper. Only the
% test year > 2007 and date < current date will be performed as date 
% information is stored in datenum format (decimal days since 01/01/0000) 
% before being output in addition not all the date information in input 
% files are in ASCII format or expressed with day, month and year information...
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data dimensions/variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - same as input.
%
%   flags       - Vector the same length as data, with flags.
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
if ~isstruct(sample_data),        error('sample_data must be a struct'); end
% if ~isvector(data),               error('data must be a vector');        end
if ~isscalar(k) || ~isnumeric(k), error('k must be a numeric scalar');   end
if ~ischar(type),                 error('type must be a string');        end

% auto logical in input to enable running under batch processing
if nargin<5, auto=false; end

paramsLog = [];
flags     = [];
dataTime  = [];

if strcmpi(sample_data.(type){k}.name, 'TIME')
    dataTime = sample_data.(type){k}.data;
else
    return;
end

qcSet    = str2double(readProperty('toolbox.qc_set'));
passFlag = imosQCFlag('good',           qcSet, 'flag');
failFlag = imosQCFlag('bad',            qcSet, 'flag');

if ~isempty(dataTime)
    sizeData = size(dataTime);
    
    % initially all data is bad
    flags = ones(sizeData, 'int8')*failFlag;
    
    % read date bounderies from imosImpossibleDateQC parameters file
    dateMin = readProperty('dateMin', fullfile('AutomaticQC', 'imosImpossibleDateQC.txt'));
    dateMax = readProperty('dateMax', fullfile('AutomaticQC', 'imosImpossibleDateQC.txt'));
    
    dateMin = datenum(dateMin, 'dd/mm/yyyy');
    if isempty(dateMax)
        dateMax = now_utc;
    else
        dateMax = datenum(dateMax, 'dd/mm/yyyy');
    end
    
    % read dataset QC parameters if exist and override previous 
    % parameters file
    currentQCtest = mfilename;
    dateMin = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMin', dateMin);
    dateMax = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMax', dateMax);
    
    paramsLog = ['dateMin=' datestr(dateMin, 'dd/mm/yyyy') ...
        ', dateMax=' datestr(dateMax, 'dd/mm/yyyy')];
    
    iGoodTime = dataTime >= dateMin;
    iGoodTime = iGoodTime & (dataTime <= dateMax);
    
    if any(iGoodTime)
        flags(iGoodTime) = passFlag;
    end
    
    if any(~iGoodTime)
        error([num2str(sum(~iGoodTime)) ' points failed Impossible date QC test in file ' sample_data.toolbox_input_file '. Try to re-play and fix this dataset when possible using the manufacturer''s software before processing it with the toolbox.']);
    end
    
    % write/update dataset QC parameters
    writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMin', dateMin);
    writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMax', dateMax);
end