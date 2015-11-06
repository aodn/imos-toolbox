function migrateAutomaticQC(previousVersionPath)
%MIGRATEAUTOMATICQC updates the default QC parameter values with
%the ones set by the user in version 2.4 of the toolbox.
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

% pair param/value config files
qcFileNames = {'imosCorrMagVelocitySetQC.txt', 'imosEchoIntensityVelocitySetQC.txt', 'imosErrorVelocitySetQC.txt', ...
    'imosHorizontalVelocitySetQC.txt', 'imosImpossibleDateQC.txt', 'imosImpossibleDepthQC.txt', ...
    'imosPercentGoodVelocitySetQC.txt', 'imosRateOfChangeQC.txt', 'imosSideLobeVelocitySetQC.txt', ...
    'imosVerticalSpikeQC.txt', 'imosVerticalVelocityQC.txt'};
directory = 'AutomaticQC';
delim = '=';

nFile = length(qcFileNames);
for n=1:nFile
    fileName = qcFileNames{n};
    
    previousQcFile  = fullfile(previousVersionPath, directory, fileName);
    currentQcFile   = fullfile('ConfigFileTemplates_DO-NOT-EDIT', directory, fileName);
    migratedQcFile  = fullfile(directory, fileName);
    
    copyfile(currentQcFile, migratedQcFile);
    
    [previousPropertiesNames, previousPropertiesValues] = listProperties(previousQcFile, delim);
    [currentPropertiesNames,  ~]                        = listProperties(currentQcFile,  delim);
    
    nProp = length(previousPropertiesNames);
    for i=1:nProp
        iCompareProperties = strcmp(previousPropertiesNames{i}, currentPropertiesNames);
        if any(iCompareProperties) && ~isempty(previousPropertiesValues{i})
            % we update the property value if the same property had been
            % documented in previous version
            writeProperty(previousPropertiesNames{i}, previousPropertiesValues{i}, migratedQcFile, delim);
        end
    end
end

% imosGlobalRangeQC
fileName = 'imosGlobalRangeQC.txt';

previousQcFile  = fullfile(previousVersionPath, directory, fileName);
currentQcFile   = fullfile('ConfigFileTemplates_DO-NOT-EDIT', directory, fileName);
migratedQcFile  = fullfile(directory, fileName);

copyfile(currentQcFile, migratedQcFile);

previousParams = importdata(previousQcFile);
currentParams  = importdata(currentQcFile);

nProp = length(previousParams);
for i=1:nProp
    iCompareParams = strcmp(previousParams{i}, currentParams);
    if ~any(iCompareParams)
        % we add the parameter if it had been
        % documented in previous version
        fid = -1;
        try
            fid = fopen(migratedQcFile, 'at');
            if fid == -1, return; end
            
            fprintf(fid, '%s\n', previousParams{i});
            fclose(fid);
        catch e
            if fid ~= -1, fclose(fid); end
            rethrow(e);
        end
    end
end

% imosRegionalRangeQC
fileName = 'imosRegionalRangeQC.txt';

previousQcFile  = fullfile(previousVersionPath, directory, fileName);
currentQcFile   = fullfile('ConfigFileTemplates_DO-NOT-EDIT', directory, fileName);
migratedQcFile  = fullfile(directory, fileName);

copyfile(currentQcFile, migratedQcFile);

[previousSite, previousParam, previousMin, previousMax] = listRegionalRange(previousQcFile);
[currentSite,  currentParam,  ~,           ~]           = listRegionalRange(currentQcFile);

nProp = length(previousSite);
for i=1:nProp
    iCompareSite  = strcmp(previousSite{i}, currentSite);
    iCompareParam = strcmp(previousParam{i}, currentParam);
    iCompareEntry = iCompareSite & iCompareParam;
    if ~any(iCompareEntry)
        % we add the missing site entry
        appendRegionalRange(migratedQcFile, previousSite{i}, previousParam{i}, ...
            previousMin(i), previousMax(i));
        disp('Please feedback this new regional range to eMII :');
        disp([previousSite{i} ', ' previousParam{i} ', ' ...
            num2str(previousMin(i)) ', ' num2str(previousMax(i))]);
        disp('');
    end
end
end

function [site, param, min, max] = listRegionalRange(file)

site  = [];
param = [];
min   = [];
max   = [];

fid = -1;
try
  fid = fopen(file, 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%s%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
  
  site  = params{1};
  param = params{2};
  min   = params{3};
  max   = params{4};

catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

end

function appendRegionalRange(file, site, param, min, max)

fid = -1;
try
  fid = fopen(file, 'at');
  if fid == -1, return; end
  
  fprintf(fid, '%s, %s, %.1f, %.1f\n', site, param, min, max);
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

end