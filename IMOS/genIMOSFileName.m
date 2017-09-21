function filename = genIMOSFileName( sample_data, suffix )
%GENIMOSFILENAME Generates an IMOS file name for the given data set.
%
% Generates a file name for the given data set. The file name is generated 
% according to the IMOS NetCDF File Naming Convention, version 1.3. Values
% for each field are retrieved from the imosFileName.txt configuration
% file. Any fields which are not present, or not set in this file are given
% a default value.
%
% Inputs:
%   sample_data - the data set to generate a file name for.
%   suffix      - file name suffix to use.
%
% Outputs:
%   filename    - the generated file name.
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: 	Brad Morris <b.morris@unsw.edu.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2,2);

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  if ~ischar(suffix),        error('suffix must be a string');      end

  %
  % all dates should be in ISO 8601 format
  %
  dateFmt = readProperty('exportNetCDF.fileDateFormat');

  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
  
  % get default config, and file config
  defCfg  = genDefaultFileNameConfig(sample_data, dateFmt, mode);
  fileCfg = readFileNameConfig(sample_data);
  
  switch mode
      case 'profile'
          % build the file name
          if strcmpi(suffix, 'png')
              filename = [sample_data.naming_authority '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'facility_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'site_code')     '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'file_version')  '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'start_date')    '_'];
              filename = [filename 'PLOT-TYPE_C-'   getVal(fileCfg, defCfg, 'creation_date')];
          else
              filename = [sample_data.naming_authority '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'facility_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'data_code')     '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'start_date')    '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'site_code')     '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'file_version')  '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'product_type')  '_'];
              filename = [filename 'C-'   getVal(fileCfg, defCfg, 'creation_date')    ];
          end
      case 'timeSeries'
          % build the file name
          if strcmpi(suffix, 'png')
              filename = [sample_data.naming_authority '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'facility_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'platform_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'file_version')  '_'];
              filename = [filename        sample_data.meta.site_id                 '_'];
              filename = [filename 'PLOT-TYPE_PARAM_C-'   getVal(fileCfg, defCfg, 'creation_date')];
          else
              filename = [sample_data.naming_authority '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'facility_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'data_code')     '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'start_date')    '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'platform_code') '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'file_version')  '_'];
              filename = [filename        getVal(fileCfg, defCfg, 'product_type')  '_'];
              filename = [filename 'END-' getVal(fileCfg, defCfg, 'end_date')      '_'];
              filename = [filename 'C-'   getVal(fileCfg, defCfg, 'creation_date')    ];
          end
  end
  
  % sanity check - ensure that file name contains 
  % only alpha numeric, hyphens, underscores and dots
  filename(regexp(filename, '[^A-Za-z0-9_\.-]')) = '-';
  %BDM 24/02/2010 - Quick fix to get rid of multiple '-'
  while ~isempty(strfind(filename,'--'))
    filename=strrep(filename,'--','-');
  end
  
  % it is assumed that the suffix is valid
  filename = [filename '.'    suffix];

  % we handle the case when the source file is a NetCDF file.
  if isfield(sample_data.meta, 'file_name') && strcmpi(suffix, 'nc')
      filename = sample_data.meta.file_name;
      
      % we need to update the creation_date
      filename(end-18:end-3) = getVal(fileCfg, defCfg, 'creation_date');
  end
end

function val = getVal(fileCfg, defCfg, fieldName)
%GETVAL Saves a few lines of code. If the given field is specified in the
% file configuration, that value is used. Otherwise reverts to the default
% configuration.
%

  if isfield(fileCfg, fieldName), val = fileCfg.(fieldName);
  else                            val = defCfg .(fieldName);
  end
end

function config = genDefaultFileNameConfig(sample_data, dateFmt, mode)
%GENDEFAULTFILENAMECONFIG Generates a default file name configuration, the
%values from which will be used if a value has not been specified in the
% imosFileName.txt configuration file.
%
  config = struct;
  
  % <facility_code>
  if isfield(sample_data.meta, 'facility_code')
      config.facility_code = sample_data.meta.facility_code;
  else
      config.facility_code = sample_data.institution;
  end
  
  % <data_code>
  config.data_code = '';
  
%   % code for raw data should contain 'R' for raw      % This is not relevant anymore
%   if sample_data.meta.level == 0, config.data_code = 'R'; end
  for k = 1:length(sample_data.variables)

    % get the data code for this parameter; don't add 
    % duplicate codes, and ignore non-IMOS parameters
    try 
      
      code = imosParameters(sample_data.variables{k}.name, 'data_code');
      if strfind(config.data_code, code), continue; end
      config.data_code(end+1) = code;
      
    catch e %#ok<NASGU>
      continue;
    end
  end
  % let's sort the resulting data code alphabetically
  config.data_code = sort(config.data_code);
  
  % <start_date>, <site_code>, <platform_code>, <file_version>
  extraChar = '';
  if strfind(dateFmt, 'Z') == length(dateFmt)
      dateFmt = dateFmt(1:end-1);
      extraChar = 'Z';
  end
  config.start_date    = [datestr(sample_data.time_coverage_start, dateFmt), extraChar];
  
  config.site_code     = sample_data.site_code;

  config.platform_code = sample_data.platform_code;
  
  config.file_version  = imosFileVersion(sample_data.meta.level, 'fileid');
  
  % <product_type>
  switch mode
      case 'profile'
          config.product_type  = ['Profile-' ...
              sample_data.meta.instrument_model];
          
      case 'timeSeries'
          config.product_type  = [...
              sample_data.meta.site_id '-' ...
              sample_data.meta.instrument_model    '-' ...
              num2str(sample_data.meta.depth)];
  end

  % remove any spaces/underscores
  config.product_type(config.product_type == ' ') = '-';
  config.product_type(config.product_type == '_') = '-';
  
  % <end_date>, <creation_date>
  config.end_date    = [datestr(sample_data.time_coverage_end, dateFmt), extraChar];
  
  config.creation_date = [datestr(sample_data.date_created, dateFmt), extraChar];
end

function config = readFileNameConfig(sample_data)
%READFILENAMECONFIG Reads in the imosFileName.txt configuration file, and
% returns the values contained within.
%
  config = struct;
  
  fileName = ['IMOS' filesep 'imosFileName.txt'];
  
  [names, values] = listProperties(fileName);
  
  for k = 1:length(names)
    if ~isempty(values{k})
        config.(names{k}) = parseAttributeValue(values{k}, sample_data, 1);
    end
  end
end
