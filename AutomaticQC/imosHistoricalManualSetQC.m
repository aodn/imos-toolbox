function [sample_data, varChecked, paramsLog] = imosHistoricalManualSetQC( sample_data, auto )
%IMOSHISTORICALMANUALSETQC automaticall re-apply manual QC performed in the past.
%
% Looks for a .mqc file next to the input raw file with the same radical
% name, loads it (is actually a .mat file containing a struc array) and
% apply relevant manual QC recorded in this file.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%   varChecked  - cell array of variables' name which have been checked
%   paramsLog   - string containing details about params' procedure to include in QC log
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
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

varChecked = {};
paramsLog  = [];

% read manual QC file for this dataset
mqcFile = [sample_data.toolbox_input_file, '.mqc'];

% we need to migrate any remnants of the old file naming convention
% for .mqc files.
[mqcPath, oldMqcFile, ~] = fileparts(sample_data.toolbox_input_file);
oldMqcFile = fullfile(mqcPath, [oldMqcFile, '.mqc']);
if exist(oldMqcFile, 'file')
    movefile(oldMqcFile, mqcFile);
end

if exist(mqcFile, 'file')
    load(mqcFile, '-mat', 'mqc');
else
    return;
end

nmqc = length(mqc);
varChecked = cell(1, nmqc);

for i=1:nmqc
    idVar   = getVar(sample_data.variables, mqc(i).nameVar);
    dataIdx = mqc(i).iData;
    flag    = mqc(i).flag;
    comment = mqc(i).comment;
    
    sample_data.variables{idVar}.flags(dataIdx) = flag;
    if ~isempty(comment)
        if ~isfield(sample_data.variables{idVar}, 'ancillary_comment')
            sample_data.variables{idVar}.ancillary_comment = comment;
        else
            if isempty(sample_data.variables{idVar}.ancillary_comment)
                sample_data.variables{idVar}.ancillary_comment = comment;
            else
                sample_data.variables{idVar}.ancillary_comment = strrep([sample_data.variables{idVar}.ancillary_comment, '. ', comment], '.. ', '. ');
            end
        end
    end
    
    varChecked{i} = mqc(i).nameVar;
end

end