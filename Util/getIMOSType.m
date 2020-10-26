function [mtype] = getIMOSType(imos_parameter_str)
% function mtype = getIMOSType(imos_parameter_str)
%
% A wrapper to get the type of an IMOS parameter
%
% Inputs:
%
% imos_parameter_str - an IMOS string name
%
% Outputs:
%
% mtype - a function handle that define the parameter
%         type
%
% Example:
% [mtype] = getIMOSType('TEMP');
% assert(isequal(mtype,@single))
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
mtype = str2func(netcdf3ToMatlabType(imosParameters(imos_parameter_str, 'type')));
end
