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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
        disp(['Warning : ' num2str(sum(~iGoodTime)) ' points failed Impossible date QC test in file ' sample_data.toolbox_input_file]);
    end
    if all(~iGoodTime)
        error('All points failed');
    end
    
    % write/update dataset QC parameters
    writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMin', dateMin);
    writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'dateMax', dateMax);
end