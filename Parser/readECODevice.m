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