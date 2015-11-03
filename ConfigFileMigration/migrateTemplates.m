function migrateTemplates(previousVersionPath)
%MIGRATETEMPLATES fills the new .txt virgin NetCDF templates with
%the values from the version 2.4 of the toolbox.
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

templateDirectory = fullfile('NetCDF', 'template');
templateFileNames = {'depth_attributes.txt', 'dimension_attributes.txt', ...
    'direction_attributes.txt', 'global_attributes_profile.txt', 'global_attributes_timeSeries.txt', ...
    'height_above_sensor_attributes.txt', 'latitude_attributes.txt', 'longitude_attributes.txt', ...
    'nominal_depth_attributes.txt', 'profile_attributes.txt', 'qc_attributes.txt', ...
    'qc_coord_attributes.txt', 'spct_attributes.txt', 'time_attributes.txt', ...
    'timeseries_attributes.txt', 'trajectory_attributes.txt', 'variable_attributes.txt'};
nTemplate = length(templateFileNames);
for n=1:nTemplate
    templateFileName = templateFileNames{n};
    
    previousFile = fullfile(previousVersionPath, templateDirectory, templateFileName);
    currentFile  = fullfile('ConfigFileTemplates_DO-NOT-EDIT', templateDirectory, templateFileName);
    migratedFile = fullfile(templateDirectory, templateFileName);
    
    if ~exist(previousFile, 'file')
        copyfile(currentFile, migratedFile);
        continue;
    end
    
    [previousTypes, previousNames, previousValues] = parseTemplate(previousFile);
    
    fidR = -1;
    fidW = -1;
    try
        % open current file for reading
        fidR = fopen(currentFile, 'rt');
        lineR = '';
        if fidR == -1, error(['couldn''t open ' currentFile ' for reading']); end
        
        % open migrated file for writing
        fidW = fopen(migratedFile, 'wt');
        if fidW == -1, error(['couldn''t open ' migratedFile ' for writing']); end
        
        % read in and parse each line
        lineR = fgetl(fidR);
        while ischar(lineR)
            % extract the attribute name and value
            tkns = regexp(lineR, ...
                '^\s*(.*\S)\s*,\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');
            
            % regexp not matching an entry
            if isempty(tkns),
                fprintf(fidW, '%s\n', lineR);
                lineR = fgetl(fidR);
                continue;
            end
            
            type = tkns{1}{1};
            name = tkns{1}{2};
            
            iCompareTypes = strcmp(type, previousTypes);
            iCompareNames = strcmp(name, previousNames);
            if any(iCompareTypes & iCompareNames)
                % we only update values already defined in previous version for
                % current one
                lineR = textscan(lineR, '%s%s', 'Delimiter', '=');
                lineR = [lineR{1}{1} '= ' previousValues{iCompareTypes & iCompareNames}];
                
            end
            fprintf(fidW, '%s\n', lineR);
            
            % get the next line
            lineR = fgetl(fidR);
        end
        
        fclose(fidR);
        fclose(fidW);
    catch e
        if fidR ~= -1, fclose(fidR); end
        if fidW ~= -1, fclose(fidW); end
        disp(lineR);
        rethrow(e);
    end
end
end


function [type, name, val] = parseTemplate(file)

type = {};
name = {};
val  = {};

fid = -1;
try
    % open file for reading
    fid = fopen(file, 'rt');
    line = '';
    if fid == -1, error(['couldn''t open ' file ' for reading']); end
    
    % read in and parse each line
    line = fgetl(fid);
    while ischar(line)
        % extract the attribute name and value
        tkns = regexp(line, ...
            '^\s*(.*\S)\s*,\s*(.*\S)\s*=\s*(.*\S)?\s*$', 'tokens');
        
        % ignore bad lines
        if isempty(tkns),
            line = fgetl(fid);
            continue;
        end
        
        type{end+1} = tkns{1}{1};
        name{end+1} = tkns{1}{2};
        val{end+1}  = tkns{1}{3};
        
        % get the next line
        line = fgetl(fid);
    end
    
    fclose(fid);
catch e
    if fid ~= -1, fclose(fid); end
    disp(line);
    rethrow(e);
end
end