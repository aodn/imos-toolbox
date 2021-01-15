function [root_path] = toolboxRootPath()
% function root_path = toolboxRootPath()
%
% Return the root path of the IMOS Toolbox
%
% Outputs:
%
% root_path - a string path of the toolbox root
%
% Example:
%
% [root_path] = toolboxRootPath();
% assert(~isempty(root_path))
% assert(any(contains(FilesInFolder(root_path),'imosToolbox.m')))
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

where_imos = which('imosToolbox.m');

if isempty(where_imos)
    error("Could not find the path to imosToolbox.m");
else
    root_path = [fileparts(which('imosToolbox.m')) filesep];
end

end
