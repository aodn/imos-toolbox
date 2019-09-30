function deviceInfo = readECODevice( filename )
%READECODEVICE parses a .dev device file retrieved from a Wetlabs ECO instrument.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%
% Outputs:
%   deviceInfo  - struct containing fields 'plotHeader' (plot header string) 
%               and struct vector 'column' of length the number of columns containing 
%               fields 'type' (string 'N/U', 'Lambda','cdom', etc...) and then fields
%               'scale', 'offset', 'measWaveLength', 'dispWaveLength', 'volts' when
%               appropriate.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%
% See http://www.wetlabs.com/products/pub/eco/ecoviewj.pdf, 
% Chapter 3. 'ECOView Device Files'.
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

% ensure that there is exactly one argument
narginchk(1, 1);
if ~ischar(filename), error('filename must contain a string'); end

deviceInfo = struct;

% open file, get everything from it as lines
fid     = -1;
lines = {};
try
    fid = fopen(filename, 'rt');
    if fid == -1, error(['couldn''t open ' filename 'for reading']); end
    
    % read in the data
    lines = textscan(fid, '%s', 'Whitespace', '\r\n');
    lines = lines{1};
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

deviceInfo.plotHeader = strrep(lines{1}, '\t', '');
dashPos = strfind(deviceInfo.plotHeader, '-');
deviceInfo.instrument = deviceInfo.plotHeader(1:dashPos-1);
deviceInfo.serial = deviceInfo.plotHeader(dashPos+1:end);

underscorePos = strfind(deviceInfo.serial, '_');
if ~isempty(underscorePos)
    deviceInfo.serial = deviceInfo.serial(1:underscorePos-1);
end

% we look for the number of columns described
nLines = length(lines);
nColumns = [];
startColDesc = NaN;
for i=2:nLines
    nColumns = regexp(lines{i}, '(?i)columns(?-i)=[0-9]+', 'Match');
    if ~isempty(nColumns)
        startColDesc = i+1;
        break;
    end
end
nColumns = str2double(nColumns{1}(length('Columns=')+1:end));

deviceInfo.columns = cell(nColumns, 1);

% we now parse the content of the columns' description
for i=1:nColumns
    deviceInfo.columns{i}.type = 'N/U';
    columnDesc = [];
    type = [];
    output = [];
    for j=startColDesc:nLines
        columnDesc = regexp(lines{j}, ['[\w\/]+=' num2str(i) '.*'], 'Match');
        if ~isempty(columnDesc)
            columnDesc = columnDesc{1};
            break;
        end
    end
    
    type = regexp(columnDesc, '[\w\/]+=', 'Match');
    type = type{1}(1:end-1);
    
    switch upper(type)
        case {'N/U', 'DKDC'}
            % do nothing
            
        case 'PAR'
            % measurements in counts with coefficients calibration
            deviceInfo.columns{i}.type = upper(type);
            im = [];
            a1 = [];
            a0 = [];
            
            for j=j+1:nLines
                if isempty(im), im = regexp(lines{j}, 'im=[\s]*([0-9\.]*)', 'tokens'); end
                if isempty(a1), a1 = regexp(lines{j}, 'a1=[\s]*([0-9\.]*)', 'tokens'); end
                if isempty(a0), a0 = regexp(lines{j}, 'a0=[\s]*([0-9\.]*)', 'tokens'); end
                if ~isempty(im) && ~isempty(a1) && ~isempty(a0)
                    deviceInfo.columns{i}.im = str2double(im{1});
                    deviceInfo.columns{i}.a0 = str2double(a0{1});
                    deviceInfo.columns{i}.a1 = str2double(a1{1});
                    break;
                end
            end
            
            if isempty(im) || isempty(a1) || isempty(a0)
                error(['couldn''t read PAR coefficients calibration from ' filename]);
            end
            
        otherwise
            % measurements with possible scale, offset and wavelengths infos
            deviceInfo.columns{i}.type = upper(type);
            format = '%*s\t%f\t%f\t%f\t%f';
            output = cell(1, 4);
            output = textscan(columnDesc, format, 'Delimiter', '\t', 'MultipleDelimsAsOne', true);
            if ~isempty(output{1}), deviceInfo.columns{i}.scale = output{1}; end
            if ~isempty(output{2}), deviceInfo.columns{i}.offset = output{2}; end
            if ~isempty(output{3}), deviceInfo.columns{i}.measWaveLength = output{3}; end
            if ~isempty(output{4}), deviceInfo.columns{i}.dispWaveLength = output{4}; end
    end
end