function [header_info, header_content, header_lines] = HeaderParser(fid, hrules, trules)
%function [header_info, header_content, header_lines] = HeaderParser(fid, hrules, trules)
%
% Read the header of a Starmon instrument given a encoding.
%
% Inputs:
%
% fid - a file identifier
% hrules - a structure that defines the regexp header rules
% trules - a structure that defines the header line tranformation rules
%
% Outputs:
%
% header_info - the header information structure processed
% header_content - A structure with header content (key/value)
% header_lines - A cell with the specific header lines
%
% Examples:
% % see parsers in the GenericParser folder
% % for hrules/trules definitions.
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

if ~isnumeric(fid)
    error('first argument should be a file id numeric')
end

if ~isstruct(hrules)
    error('second argument should be a header rules structure')
end

if ~isstruct(trules)
    error('third argument should be a header transform structure')
end

narginchk(3, 3);
stopfirst = true;
header_lines = readLinesWithRegex(fid, hrules.line_signature(), stopfirst);

if isAnyCellItemEmpty(header_lines)
    error('One Header line was not read correctly')
end

header_content = readHeaderDict(header_lines, hrules.func, hrules.key_value_signature());

if isAnyCellItemEmpty(header_content)
    error('One Header Content was not processed correctly')
end

header_info = translateHeaderText(header_content, trules);
end
