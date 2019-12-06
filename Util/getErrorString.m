function errorString = getErrorString(e)
%GETERRORSTRING retrieve the information from the error stack and produce a
%string out of it.
%
%
% Inputs:
%   e           - exception object
%
% Outputs:
%   errorString - string describing the error faced
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
narginchk(1,1);

errorString = '';

errorString = sprintf('%s\n', e.message);
s = e.stack;
for l=1:length(s)
    errorString = [errorString, sprintf('\t%s\t(%s: line %i)\n', s(l).name, s(l).file, s(l).line)];
end

end