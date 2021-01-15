function [pcell] = struct2parameters(astruct)
% function [pcell] = struct2parameters(astruct)
%
% Convert a struct to a cell Parameter {'key0','value0','key1','value1',...}.
%
% Inputs:
%
% astruct - a named struct with values.
%
% Outputs:
%
% pcell - a parameter cell.
%
% Example:
%
% astruct = struct('one',1,'two',2);
% [pcell] = struct2parameters(astruct);
% assert(strcmp(pcell{1},'one'))
% assert(pcell{2}==1)
% assert(strcmp(pcell{3},'two'))
% assert(pcell{4}==2)
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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
keys = fieldnames(astruct);
values = struct2cell(astruct);
pcell = cell(1, numel(keys)*2);
c=-1;
for k = 1:length(keys)
    c=c+2;
    pcell{c} = keys{k};
    pcell{c + 1} = values{k};
end

end
