function t = templateType( templateDir, name, temp, mode )
%TEMPLATETYPE Returns the type of the given NetCDF attribute, as specified
% in the associated template file.
%
% In the NetCDF attribute template files, attributes can have one of the
% following types.
%
%   S - String
%   N - Numeric
%   D - Date
%   Q - Quality control (either byte or char, depending on the QC set in use)
%
% Inputs:
%   templateDir - the path to the directory which contains all the
%   templates file.
%   name - the attribute name
%   temp - what kind of attribute - 'global', 'time', 'depth', 'latitude', 
%          'longitude', 'variable', 'qc' or 'qc_coord'
%   mode - Toolbox data type mode.
%
% Outputs:
%   t    - the type of the attribute, one of 'S', 'N', 'D', or 'Q', or
%          empty if there was no such attribute.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(3,4);

if ~ischar(templateDir), error('templateDir must be a string'); end
if ~ischar(name), error('name must be a string'); end
if ~ischar(temp), error('temp must be a string'); end

% matlab no-leading-underscore kludge
if name(end) == '_', name = ['_', name(1:end-1)]; end

persistent global_template;
persistent var_templates;

isGlobal = false;

if strcmpi(temp, 'global')
    temp = [temp '_attributes_' mode '.txt'];
    isGlobal = true;
else
    % let's handle the case temp is a parameter name and we have multiple 
    % same param distinguished by "_1", "_2", etc...
    iLastUnderscore = strfind(temp, '_');
    if iLastUnderscore > 0
        iLastUnderscore = iLastUnderscore(end);
        if length(temp) > iLastUnderscore
            if ~isnan(str2double(temp(iLastUnderscore+1:end)))
                temp = temp(1:iLastUnderscore-1);
            end
        end
    end

    var = temp;
    temp = [temp '_attributes.txt'];
end

path = templateDir;
if isempty(path) || ~exist(path, 'dir')
    path = '';
    if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
    if isempty(path), path = pwd; end
    path = fullfile(path, 'NetCDF', 'template');
end

filepath = fullfile(path, temp);
        
if isGlobal
    if isempty(global_template)        
        global_template = readTemplate(filepath);
    end
    
    t = getTemplate(global_template, name);
else
    if isempty(var_templates)
        var_templates.(var) = readTemplate(filepath);
    else
        if ~isfield(var_templates, var)
            var_templates.(var) = readTemplate(filepath);
        end
    end
    
    t = getTemplate(var_templates.(var), name);
end
end

function t = getTemplate(template, name)
    
    % pull out the type, attribute name and value
    [~, type] = regexp(template, ['^\s*(.*\S)\s*,\s*(.*' name ')\s*=\s*(.*\S)?\s*$'], 'match', 'tokens');
    type(cellfun('isempty', type)) = [];
    if ~isempty(type)
        t = type{1}{1}{1};
    else
        t = '';
    end
end

function lines = readTemplate(filepath)
    try
        fid = -1;
        fid = fopen(filepath, 'rt');

        if fid == -1, error(['could not open file ' filepath]); end

        lines = textscan(fid, '%s', 'Delimiter', '', 'CommentStyle', '%');
        lines = lines{1};

        fclose(fid);
    catch e
        if fid ~= -1, fclose(fid); end
        rethrow(e);
    end
end
