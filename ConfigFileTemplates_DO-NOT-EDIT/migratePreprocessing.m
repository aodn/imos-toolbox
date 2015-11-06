function migratePreprocessing(previousVersionPath)
%MIGRATEPREPROCESSING fills the Preprocessing/*.txt original templates with
%the properties from the version 2.4 of the toolbox.
%
% Inputs:
%   previousVersionPath - Path to the previous version of the toolbox where 
%                     previously filled config files can be found.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
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

preprocessingFileNames = {'aquatrackaPP.txt', 'CTDDepthBinPP.txt', 'depthPP.txt', 'pressureRelPP.txt', 'rinkoDoPP.txt', 'soakStatusPP.txt', ...
    'timeOffsetPP.txt', 'transformPP.txt', 'variableOffsetPP.txt'};
delims = {',', ',', ',', ',', ',', ',', ',', '=', '='};
updateOnly = [true, true, true, true, true, true, false, false, false];
preprocessingFolder = 'Preprocessing';

nPP = length(preprocessingFileNames);
for pp=1:nPP
    previousFile  = fullfile(previousVersionPath, preprocessingFolder, preprocessingFileNames{pp});
    currentFile   = fullfile('ConfigFileTemplates_DO-NOT-EDIT', preprocessingFolder, preprocessingFileNames{pp});
    migratedFile  = fullfile(preprocessingFolder, preprocessingFileNames{pp});
    
    copyfile(currentFile, migratedFile);
    
    % check if file previously existed
    if ~exist(previousFile, 'file'), continue; end;
    
    delim = delims{pp};
    [previousPropertiesNames, previousPropertiesValues] = listProperties(previousFile, delim);
    
    nProp = length(previousPropertiesNames);
    if updateOnly(pp)
        % update entries in the migrated file if they exist in previous file
        [currentPropertiesNames,  ~] = listProperties(currentFile, delim);
        for i=1:nProp
            iCompareProperties = strcmp(previousPropertiesNames{i}, currentPropertiesNames);
            if any(iCompareProperties)
                writeProperty(previousPropertiesNames{i}, previousPropertiesValues{i}, migratedFile, delim);
            end
        end
    else
        % taking all the previous entries and make sure they exist and are updated
        % in the migrated file
        for i=1:nProp
            writeProperty(previousPropertiesNames{i}, previousPropertiesValues{i}, migratedFile, delim);
        end
    end
end