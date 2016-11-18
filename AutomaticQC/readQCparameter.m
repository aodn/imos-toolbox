function value = readQCparameter(rawDataFile, QCtest, param, value)
%READQCPARAMETER Return the value of the specified parameter from the QC 
%parameter file associated to the raw data file.
%
% This function provides a simple interface to retrieve the values of
% parameters stored in a QC parameter file.
%
% A 'QC parameter' file is a 'mat' file which contains a pqc struct which 
% fields are the name of a QC test and subfields the name of their parameters 
% which contain this parameter value.
%
% Inputs:
%
%   rawDataFile - Name of the raw data file. Is used to build the QC
%               property file name (same root but different extension).
%
%   QCtest      - Name of the QC test. If the name does not map to a QC 
%               test then the default value from (QCtest).txt is returned.
%
%   param       - Name of the QC test parameter to be retrieved. If the
%               name does not map to a parameter listed in the QC test of 
%               the QC parameter file, an error is raised.
%
%   value       - Value of the default QC parameter.
%
% Outputs:
%   value       - Value of the dataset QC parameter.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(4,4);

if ~ischar(rawDataFile), error('rawDataFile must be a string'); end
if ~ischar(QCtest),      error('QCtest must be a string');      end
if ~ischar(param),       error('param must be a string');       end

pqcFile = [rawDataFile, '.pqc'];

% we need to migrate any remnants of the old file naming convention
% for .pqc files.
[pqcPath, oldPqcFile, ~] = fileparts(rawDataFile);
oldPqcFile = fullfile(pqcPath, [oldPqcFile, '.pqc']);
if exist(oldPqcFile, 'file')
    movefile(oldPqcFile, pqcFile);
end

pqc = struct([]);

if exist(pqcFile, 'file')
    load(pqcFile, '-mat', 'pqc');
    
    if isfield(pqc, QCtest)
        if strcmpi(param, '*')
            value{1} = fieldnames(pqc.(QCtest));
            for i=1:length(value{1})
                value{2}{i} = pqc.(QCtest).(value{1}{i});
            end
        else
            if isfield(pqc.(QCtest), param)
                value = pqc.(QCtest).(param);
            else
                error([param ' is not a parameter of ' QCtest]);
            end
        end
    end
end
