function value = readDatasetParameter(rawDataFile, routine, param, value)
%READDATASETPARAMETER Returns the value of a specified parameter from the PP or QC 
%parameter file associated to a raw data file.
%
% This function provides a simple interface to retrieve the values of
% parameters stored in a PP or QC parameter file.
%
% A 'parameter' file is a 'mat' file which contains a p structure which 
% fields are the name of a PP or QC routine and subfields the name of their parameters 
% which contain this parameter value.
%
% Inputs:
%
%   rawDataFile - Name of the raw data file. Is used to build the parameter
%               file name (same root but different extension).
%
%   routine     - Name of the PP or QC routine. If the name does not map to any 
%               existing routine then the default value is returned.
%
%   param       - Name of the routine parameter to be retrieved. If the
%               name does not map to a parameter listed in the routine of 
%               the parameter file, the value of the default parameter is returned.
%
%   value       - Value of the default parameter.
%
% Outputs:
%   value       - Value of the dataset parameter.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(4,4);

if ~ischar(rawDataFile), error('rawDataFile must be a string'); end
if ~ischar(routine),     error('routine must be a string');     end
if ~ischar(param),       error('param must be a string');       end

switch lower(routine(end-1:end))
    case 'qc'
        pType = 'pqc';
        
    case 'pp'
        pType = 'ppp';
        
    otherwise
        return;
end
pFile = [rawDataFile, '.', pType];

% we need to migrate any remnants of the old file naming convention
% for .pqc files.
[pPath, oldPFile, ~] = fileparts(rawDataFile);
oldPFile = fullfile(pPath, [oldPFile, '.', pType]);
if exist(oldPFile, 'file')
    movefile(oldPFile, pFile);
end

ppp = struct([]);
pqc = struct([]);

if exist(pFile, 'file')
    load(pFile, '-mat', pType);
    
    switch pType
        case 'pqc'
            p = pqc;
            
        case 'ppp'
            p = ppp;
    end
    
    if isfield(p, routine)
        if strcmpi(param, '*')
            value{1} = fieldnames(p.(routine));
            for i=1:length(value{1})
                value{2}{i} = p.(routine).(value{1}{i});
            end
        else
            if isfield(p.(routine), param)
                value = p.(routine).(param);
            end
        end
    end
end
