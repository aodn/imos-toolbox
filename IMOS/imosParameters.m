function value = imosParameters( short_name, field )
%IMOSPARAMETERS Returns IMOS compliant standard name, units of measurement, 
% data code, fill value, valid min/max value or type given the short parameter name.
%
% The list of all IMOS parameters is stored in a file 'imosParameters.txt'
% which is in the same directory as this m-file.
%
% The file imosParameters.txt contains a list of all parameters for which an
% IMOS compliant identifier (the short_name) exists. This function looks up the 
% given short_name and returns the corresponding standard name, long name, 
% units of measurement, data code, fill value, valid min/max value or type. If the 
% given short_name is not in the list of IMOS parameters, a default value is 
% returned.
%
% Currently, requests for long name and standard name return the same value, 
% unless the requested field is the standard name, and the parameter is not a
% CF-standard parameter, in which case an empty string is returned.
%
% Inputs:
%   short_name  the IMOS parameter name
%   field      - either 'standard_name', 'long_name', 'uom', 'positive', 'reference_datum', 'data_code',
%                'fill_value', 'valid_min', 'valid_max' or 'type',
%
% Outputs:
%   value      - the IMOS standard name, unit of measurement, direction positive, reference datum, data code, 
%                fill value, valid min/max value or type, whichever was requested.
%
% Author:           Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:      Guillaume Galibert <guillaume.galibert@utas.edu.au>
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

narginchk(2, 2);
if ~ischar(short_name), error('short_name must be a string'); end
if ~ischar(field),      error('field must be a string');      end

value = nan;

% account for numbered parameters (if the dataset 
% contains more than one variable of the same name)
match = regexp(short_name, '_\d$');
if ~isempty(match), short_name(match:end) = ''; end

% get the location of this m-file, which is 
% also the location of imosParamaters.txt
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'IMOS');

fid = -1;
persistent params; % we actually only need to read the parmeters file once and this will improve performances

if isempty(params)
    try
        fid = fopen([path filesep 'imosParameters.txt'], 'rt');
        if fid == -1, return; end
        
        params = textscan(fid, '%s%d%s%s%s%s%s%f%f%f%s', ...
            'delimiter', ',', 'commentStyle', '%');
        fclose(fid);
    catch e
        if fid ~= -1, fclose(fid); end
        rethrow(e);
    end
end
names          = params{1};
cfCompliance   = params{2};
standard_names = params{3};
uoms           = params{4};
positives      = params{5};
datums         = params{6};
data_codes     = params{7};
fillValues     = params{8};
validMins      = params{9};
validMaxs      = params{10};
varType        = params{11};

iMatchName = strcmpi(short_name, names);
if any(iMatchName)
    switch field
        case 'standard_name',
            if ~cfCompliance(iMatchName),
                value = '';
            else
                value = standard_names{iMatchName};
            end
        case 'long_name',       value = standard_names{iMatchName};
        case 'uom'
            value = uoms{iMatchName};
            if strcmpi(value, 'percent'), value = '%'; end
        case 'positive',        value = positives     {iMatchName};
        case 'reference_datum', value = datums        {iMatchName};
        case 'data_code',       value = data_codes    {iMatchName};
        case 'fill_value',      value = fillValues    (iMatchName);
        case 'valid_min',       value = validMins     (iMatchName);
        case 'valid_max',       value = validMaxs     (iMatchName);
        case 'type',            value = varType       {iMatchName};
    end
end

% provide default values for unrecognised parameters
if isnan(value)    
    switch field
        case 'standard_name',  value = '';
        case 'long_name',      value = short_name;
        case 'uom',            value = '?';
        case 'positive',       value = '';
        case 'reference_datum',value = '';
        case 'data_code',      value = '';
        case 'fill_value',     value = 999999.0;
        case 'valid_min',      value = [];
        case 'valid_max',      value = [];
        case 'type',           value = 'double';
    end
end
