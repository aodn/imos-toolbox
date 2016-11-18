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
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
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