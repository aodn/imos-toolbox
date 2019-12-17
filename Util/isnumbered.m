function [bool, num] = isnumbered(astr)
% function [bool,num] = isnumbered(astr)
%
% Detect if a string is numbered, i.e.
% got a underscore followed by a number
%
% Inputs:
%
% astr - A string
%
% Outputs:
%
% bool - A boolean to identify a numbered string
% num - a integer representation of the number
%
% Example:
%
% astr = 'TEMP';
% [bool] = isnumbered(astr);
% assert(~bool);
% astr = 'TEMP_2';
% [bool] = isnumbered(astr);
% assert(bool);
% astr = 'TEMP_ERATURE';
% [bool] = isnumbered(astr);
% assert(~bool);
% astr = 'TEMP_ERATURE_444';
% [bool,num] = isnumbered(astr);
% assert(bool);
% assert(isequal(num,444));
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

split = strsplit(astr, '_');
num = str2double(split{end});
bool = ~isnan(num);

end
