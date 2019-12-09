function [datacell] = convertVariables(datastruct, hvmap, hdmap, coordinates)
% function [datacell] = convertVariables(datastruct,hvmap,hdmap,coordinates)
%
% Convert data fields to IMOS toolbox data structures within a cell.
%
% Conversion is done given a header map, dimension map
% and coordinate string, using name resolution and type casting.
%
% Inputs:
%
% datastruct - a nested structure where fieldnames are the header
%            variable names
%
% hvmap - a containers.Map where keys are header variable
%        names and values are IMOS names.
%
% hdmap - a containers.Map where keys are header dimension
%        names and values are arrays of dimensional indexes.
%
% coordinates - a string with all coordinates separated by space.
%
% Outputs:
%
% datacell - an cell with IMOS Toolbox variable entry structured
%
% Example:
% datastruct = struct('Temperature',[1,2,3]);
% hvmap = containers.Map('Temperature','TEMP');
% hdmap = containers.Map('Temperature',[1]);
% coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
% [datacell] = convertVariables(datastruct,hvmap,hdmap,coordinates);
% assert(isequal(datacell{1}.data,datacell{1}.typeCastFunc(datastruct.Temperature)));
% assert(isequal(datacell{1}.coordinates,coordinates));
% assert(isequal(datacell{1}.dimensions,[1]));
% assert(isequal(datacell{1}.comment,''));
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

datacell = {};
onames = fieldnames(datastruct);

newvar = struct();
split_underscore = @(x) strsplit(x, '_');
cell_select = @(x, k) x{k};
non_numbered_name = @(x) cell_select(split_underscore(x), 1);

c = 0;

for k = 1:length(onames)
    oldname = onames{k};

    if isnumbered(oldname)
        kname = non_numbered_name(oldname);
    else
        kname = oldname;
    end

    if hvmap.isKey(kname)
        c = c + 1;
        defaultname = hvmap(kname);

        newname = resolveIMOSName(datacell, defaultname);
        newvar.dimensions = hdmap(kname);
        newvar.name = newname;
        newvar.typeCastFunc = getIMOSType(newname);
        newvar.data = newvar.typeCastFunc(datastruct.(oldname));
        newvar.coordinates = coordinates;
        newvar.comment = '';

        datacell{c} = newvar;
    end

end

end
