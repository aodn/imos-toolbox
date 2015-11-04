function migrateSites(previousVersionPath)
%MIGRATESITES fills the new imosSites.txt virgin template with
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

fileName = 'imosSites.txt';
directory = 'IMOS';

previousPropertiesFile  = fullfile(previousVersionPath, directory, fileName);
currentPropertiesFile   = fullfile('ConfigFileTemplates_DO-NOT-EDIT', directory, fileName);
migratedPropertiesFile  = fullfile(directory, fileName);

copyfile(currentPropertiesFile, migratedPropertiesFile);

[previousName, previousNominalLongitude, previousNominalLatitude, previousLongitudePlusMinusThreshold, ...
    previousLatitudePlusMinusThreshold, previousDistanceKmPlusMinusThreshold] = listSites(previousPropertiesFile);
[currentName,  ~,                        ~,                       ~,                                   ...
    ~,                                  ~]                                    = listSites(currentPropertiesFile);

nProp = length(previousName);
for i=1:nProp
    iCompareProperties = strcmp(previousName{i}, currentName);
    if ~any(iCompareProperties)
        % we add the missing site entry
        appendSite(migratedPropertiesFile, previousName{i}, previousNominalLongitude(i), ...
            previousNominalLatitude(i), previousLongitudePlusMinusThreshold(i), ...
            previousLatitudePlusMinusThreshold(i), previousDistanceKmPlusMinusThreshold(i));
        disp('Please feedback this new Site to eMII :');
        disp([previousName{i} ', ' num2str(previousNominalLongitude(i), '%12.8f') ', ' ...
            num2str(previousNominalLatitude(i), '%12.8f') ', ' num2str(previousLongitudePlusMinusThreshold(i)) ', ' ...
            num2str(previousLatitudePlusMinusThreshold(i)) ', ' num2str(previousDistanceKmPlusMinusThreshold(i))]);
        disp('');
    end
end
end

function [name, nominalLongitude, nominalLatitude, longitudePlusMinusThreshold, latitudePlusMinusThreshold, distanceKmPlusMinusThreshold] = listSites(file)

name                           = [];
nominalLongitude               = [];
nominalLatitude                = [];
latitudePlusMinusThreshold     = [];
longitudePlusMinusThreshold    = [];
distanceKmPlusMinusThreshold   = [];

fid = -1;
try
  fid = fopen(file, 'rt');
  if fid == -1, return; end
  
  params = textscan(fid, '%s%12.8f%12.8f%f%f%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
  
  name                           = params{1};
  nominalLongitude               = params{2};
  nominalLatitude                = params{3};
  latitudePlusMinusThreshold     = params{4};
  longitudePlusMinusThreshold    = params{5};
  distanceKmPlusMinusThreshold   = params{6};
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

end

function appendSite(file, name, nominalLongitude, nominalLatitude, longitudePlusMinusThreshold, latitudePlusMinusThreshold, distanceKmPlusMinusThreshold)

fid = -1;
try
  fid = fopen(file, 'at');
  if fid == -1, return; end
  
  fprintf(fid, '%s, %12.8f, %12.8f, %f, %f, %f\n', name, nominalLongitude, nominalLatitude, longitudePlusMinusThreshold, latitudePlusMinusThreshold, distanceKmPlusMinusThreshold);
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

end
