function [lines] = readLinesWithRegex(fid, re_signature, stopfirst)
%function [lines] = readLinessWithRegex(fid, re_signature, stopfirst);
%
% Read an in memory file line by line using
% a regex signature until the match fails or until the end of file.
%
% Inputs:
%
% fid - integer - the file id
% re_signature - string - a regular expr to detect a header line
% stopfirst - boolean - switch to stop at first unmatch.
%
% Outputs:
%
% lines - a cell containing the lines
%
% Example:
%
% fid = fopen([toolboxRootPath() 'data/testfiles/JFE/v000/20160112_0419_ACLW-USB_0341_041745_A.csv']);
% re_signature = '^((?!\[Item\]).+)$';
% [mlines] = readLinesWithRegex(fid,re_signature,true);
% assert(contains(lower(mlines{1}),'infinity'));
% assert(any(contains(mlines,'Head')));
% assert(~any(contains(mlines,'Item')));
%
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

if nargin < 2
    error('Not enough input arguments')
elseif nargin < 3
    stopfirst = true;
end

if ~ischar(re_signature)
    error('second argument is not a regular expression')
end

lines = cell(1, 1);
lc = 0;

while ~feof(fid)
    fpos = ftell(fid);
    aline = fgetl(fid);
    r = regexpi(aline, re_signature);
    is_match = ~isempty(r);

    if is_match
        lc = lc + 1;
        lines{lc} = aline;
    else

        if stopfirst
            fseek(fid, fpos, 'bof'); %go back one line when failing
            break
        end

    end

end

end
