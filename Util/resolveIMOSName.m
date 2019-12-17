function [newname] = resolveIMOSName(vcell, iname)
% function [newname] = resolveIMOSName(vcell,iname)
%
% Generate a unique name generate based on the state
% content of vcell.
%
% Inputs:
%
% vcell - original cell containing IMOS toolbox structure variables
% iname - the IMOS variable name.
%
% Outputs:
%
% newname - a string.
%
% Example:
%
% vcell = {struct('name','TEMP'),struct('name','TEMP_2')};
% name = 'TEMP';
% newname = resolveIMOSName(vcell,name);
% assert(strcmp(newname,'TEMP_3'));
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
newname = resolveString(vcell,iname,@getVar);
end
