function filename = exportNetCDF( sample_data, dest, mode )
%EXPORTNETCDF Export the given sample data to a NetCDF file.
%
% Export the given sample and calibration data to a NetCDF file. The file is 
% saved to the given destination directory. The file name is generated by the
% genIMOSFileName function.
%
% Inputs:
%   sample_data - a struct containing sample data for one process level.
%   dest        - Destination directory to save the file.
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   filename    - String containing the absolute path of the saved NetCDF file.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  error(nargchk(3, 3, nargin));

  if ~isstruct(sample_data), error('sample_data must be a struct'); end
  if ~ischar(dest),          error('dest must be a string');        end

  % check that destination is a directory
  [stat atts] = fileattrib(dest);
  if ~stat || ~atts.directory || ~atts.UserWrite
    error([dest ' does not exist, is not a directory, or is not writeable']);
  end

  % generate the filename
  filename = genIMOSFileName(sample_data, 'nc');
  filename = [dest filesep filename];
  
  fid = netcdf.create(filename, 'NC_NOCLOBBER');
  if fid == -1, error(['could not create ' filename]); end
  
  dateFmt = readProperty('exportNetCDF.dateFormat');
  qcSet   = str2double(readProperty('toolbox.qc_set'));
  qcType  = imosQCFlag('', qcSet, 'type');
  qcDimId = [];
  
  try  
    %
    % the file is created in the following order
    %
    % 1. global attributes
    % 2. dimensions / coordinate variables
    % 3. variable definitions
    % 4. data
    % 
    globConst = netcdf.getConstant('NC_GLOBAL');

    %
    % global attributes
    %
    globAtts = sample_data;
    globAtts = rmfield(globAtts, 'meta');
    globAtts = rmfield(globAtts, 'variables');
    globAtts = rmfield(globAtts, 'dimensions');    
    
    % let's add history information from log
    if ~isempty(sample_data.meta.log)
      globAtts.history = cellfun(@(x)(sprintf('%s\n', x)), ...
        sample_data.meta.log, 'UniformOutput', false);
      globAtts.history = [globAtts.history{:}];
      globAtts.history = globAtts.history(1:end-1);
    end
    
    putAtts(fid, globConst, [], globAtts, 'global', 'double', dateFmt, mode);
    
    % if the QC flag values are characters, we must define 
    % a dimension to force the maximum value length to 1
    if strcmp(qcType, 'char')
      qcDimId = netcdf.defDim(fid, 'qcStrLen', 1);
    end

    % 
    % define string lengths
    % dimensions and variables of cell type contain strings
    % define stringNN dimensions when NN is a power of 2 to hold strings
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    str(1) = 0;
    for m = 1:length(dims)
        stringlen = 0;
        if iscell(dims{m}.data)
            stringlen = ceil(log2(max(cellfun('length', dims{m}.data)))) + 1; %+1 because we need to take into account the case 2^0 = 1
            str(stringlen) = 1; %#ok<AGROW>
        end
        sample_data.dimensions{m}.stringlen = stringlen;
    end
    for m = 1:length(vars)
        stringlen = 0;
        if iscell(vars{m}.data)
            stringlen = ceil(log2(max(cellfun('length', vars{m}.data)))) + 1; %+1 because we need to take into account the case 2^0 = 1
            str(stringlen) = 1; %#ok<AGROW>
        end
        sample_data.variables{m}.stringlen = stringlen;
    end
    
    stringd = zeros(length(str));
    for m = 1:length(str)
        if str(m)
            len = 2 ^ m-1; %-1 because we need to take into account the case 2^0 = 1
            if len > 1
                stringd(m) = netcdf.defDim(fid, [ 'STRING' int2str(len) ], len);
            end
        end
    end
    
    %
    % dimension and coordinate variable definitions
    %
    dims = sample_data.dimensions;
    nDims = length(dims);
    dimNetcdfType = cell(nDims, 1);
    for m = 1:nDims
          
      dims{m}.name = upper(dims{m}.name);
      
      dimAtts = dims{m};
      dimAtts = rmfield(dimAtts, 'data');
      if isfield(dimAtts, 'flags'), dimAtts = rmfield(dimAtts, 'flags'); end
      dimAtts = rmfield(dimAtts, 'stringlen');
      
      if isfield(dims{m}, 'flags')
          % add the QC variable (defined below)
          % to the ancillary variables attribute
          dimAtts.ancillary_variables = [dims{m}.name '_quality_control'];
      end

      % create dimension
      did = netcdf.defDim(fid, dims{m}.name, length(dims{m}.data));

      % create coordinate variable and attributes
      if iscell(dims{m}.data)
          dimNetcdfType{m} = 'char';
          vid = netcdf.defVar(fid, dims{m}.name, dimNetcdfType{m}, ...
              [ stringd(dims{m}.stringlen) did ]);
      else
          dimNetcdfType{m} = imosParameters(dims{m}.name, 'type');
          vid = netcdf.defVar(fid, dims{m}.name, dimNetcdfType{m}, did);
      end
      putAtts(fid, vid, dims{m}, dimAtts, lower(dims{m}.name), dimNetcdfType{m}, dateFmt, mode);
      
      % save the netcdf dimension and variable IDs 
      % in the dimension struct for later reference
      sample_data.dimensions{m}.did   = did;
      sample_data.dimensions{m}.vid   = vid;
      
      if isfield(dims{m}, 'flags')
          % create the ancillary QC variable
          qcvid = addQCVar(...
              fid, sample_data, m, [qcDimId did], 'dim', qcType, dateFmt);
          sample_data.dimensions{m}.qcvid = qcvid;
      end
    end
    
    
    %
    % variable (and ancillary QC variable) definitions
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    nVars = length(vars);
    varNetcdfType = cell(nVars, 1);
    for m = 1:nVars

      varname = vars{m}.name;
      
      % get the dimensions for this variable
      dimIdxs = vars{m}.dimensions;
      lenDimIdxs = length(dimIdxs);
      dids = nan(1, lenDimIdxs);
      for n = 1:lenDimIdxs, dids(n) = dims{dimIdxs(n)}.did; end
      
      % reverse dimension order - matlab netcdf.defvar requires 
      % dimensions in order of fastest changing to slowest changing. 
      % The time dimension is always first in the variable.dimensions 
      % list, and is always the slowest changing.
      dids = fliplr(dids);
      
      % create the variable
      if iscell(vars{m}.data)
          varNetcdfType{m} = 'char';
          if vars{m}.stringlen > 1
              vid = netcdf.defVar(fid, varname, varNetcdfType{m}, ...
                  [ stringd(vars{m}.stringlen) did ]);
          else
              vid = netcdf.defVar(fid, varname, varNetcdfType{m}, did);
          end
      else
          varNetcdfType{m} = imosParameters(varname, 'type');
          vid = netcdf.defVar(fid, varname, varNetcdfType{m}, dids);
      end
      varAtts = vars{m};
      varAtts = rmfield(varAtts, 'data');
      varAtts = rmfield(varAtts, 'dimensions');
      varAtts = rmfield(varAtts, 'flags');
      varAtts = rmfield(varAtts, 'stringlen');
      
      % add the QC variable (defined below) 
      % to the ancillary variables attribute
      varAtts.ancillary_variables = [varname '_quality_control'];

      % add the attributes
      putAtts(fid, vid, vars{m}, varAtts, 'variable', varNetcdfType{m}, dateFmt, mode);
      
      % create the ancillary QC variable
      qcvid = addQCVar(...
        fid, sample_data, m, [qcDimId dids], 'var', qcType, dateFmt);
      
      % save variable IDs for later reference
      sample_data.variables{m}.vid   = vid;
      sample_data.variables{m}.qcvid = qcvid;
    end

    % we're finished defining dimensions/attributes/variables
    netcdf.endDef(fid);

    %
    % coordinate variable (and ancillary variable) data
    %
    dims = sample_data.dimensions;
    for m = 1:length(dims)
      
      % dimension data
      vid     = dims{m}.vid;
      data    = dims{m}.data;
      stringlen = dims{m}.stringlen;
      typeCastFunction = str2func(netcdf3ToMatlabType(dimNetcdfType{m}));
      
      % translate time from matlab serial time (days since 0000-00-00 00:00:00Z)
      % to IMOS mandated time (days since 1950-01-01T00:00:00Z)
      if strcmpi(dims{m}.name, 'TIME')
          data = data - datenum('1950-01-01 00:00:00');
      end
      
      if isnumeric(data) && isfield(dims{m}, 'FillValue_')
          % replace NaN's with fill value
          data(isnan(data)) = dims{m}.FillValue_;
      end
      
      data = typeCastFunction(data);
      if isnumeric(data)
          netcdf.putVar(fid, vid, data);
      elseif iscell(data)
          if stringlen > 1
              netcdf.putVar(fid, vid, zeros(ndims(data), 1), fliplr(size(data)), data);
          else
              netcdf.putVar(fid, vid, data);
          end
      end
      
      if isfield(dims{m}, 'flags')
          % ancillary QC variable data
          flags   = dims{m}.flags;
          qcvid   = dims{m}.qcvid;
          typeCastFunction = str2func(netcdf3ToMatlabType(qcType));
          flags = typeCastFunction(flags);
          netcdf.putVar(fid, qcvid, flags);
      end
    end

    %
    % variable (and ancillary variable) data
    %
    vars = sample_data.variables;
    for m = 1:length(vars)

      % variable data
      data    = vars{m}.data;
      flags   = vars{m}.flags;
      vid     = vars{m}.vid;
      qcvid   = vars{m}.qcvid;
      stringlen = vars{m}.stringlen;
      typeCastFunction = str2func(netcdf3ToMatlabType(varNetcdfType{m}));
      
      % translate time from matlab serial time (days since 0000-00-00 00:00:00Z)
      % to IMOS mandated time (days since 1950-01-01T00:00:00Z)
      if strcmpi(vars{m}.name, 'TIME')
          data = data - datenum('1950-01-01 00:00:00');
      end
      
      % transpose required for multi-dimensional data, as matlab 
      % requires the fastest changing dimension to be first. 
      % of more than two dimensions.
      nDims = length(vars{m}.dimensions);
      if nDims > 1, data = permute(data, nDims:-1:1); end
      
      if isnumeric(data) && isfield(vars{m}, 'FillValue_')
          % replace NaN's with fill value
          data(isnan(data)) = vars{m}.FillValue_;
      end
      
      data = typeCastFunction(data);
      if isnumeric(data)
          netcdf.putVar(fid, vid, data);
      elseif iscell(data)
          if stringlen > 1
              netcdf.putVar(fid, vid, zeros(ndims(data), 1), fliplr(size(data)), data);
          else
              netcdf.putVar(fid, vid, data);
          end
      end
      
      % ancillary QC variable data
      typeCastFunction = str2func(netcdf3ToMatlabType(qcType));
      flags = typeCastFunction(flags);
      
      if nDims > 1, flags = permute(flags, nDims:-1:1); end
      
      netcdf.putVar(fid, qcvid, flags);
    end

    %
    % and we're done
    %
    netcdf.close(fid);
  
  % ensure that the file is closed in the event of an error
  catch e
    try netcdf.close(fid); catch ex, end
    if exist(filename, 'file'), delete(filename); end
    rethrow(e);
  end
end

function vid = addQCVar(...
  fid, sample_data, varIdx, dims, type, netcdfType, dateFmt)
%ADDQCVAR Adds an ancillary variable for the variable with the given index.
%
% Inputs:
%   fid         - NetCDF file identifier
%   sample_data - Struct containing entire data set
%   varIdx      - Index into sample_data.variables, specifying the
%                 variable.
%   dims        - Vector of NetCDF dimension identifiers.
%   type        - either 'dim' or 'var', to differentiate between
%                 coordinate variables and data variables.
%   netcdfType  - The netCDF type in which the flags should be output.
%   dateFmt     - Date format in which date attributes should be output.
%
% Outputs:
%   vid         - NetCDF variable identifier of the QC variable that was 
%                 created.
%
  switch(type)
    case 'dim'
      var = sample_data.dimensions{varIdx};
      template = 'qc_coord';
    case 'var'
      var = sample_data.variables{varIdx};
      template = 'qc';
    otherwise
      error(['invalid type: ' type]);
  end
  
  path = readProperty('toolbox.templateDir');
  if isempty(path) || ~exist(path, 'dir')
    path = fullfile(pwd, 'NetCDF', 'template');
  end
  
  varname = [var.name '_quality_control'];
  
  qcAtts = parseNetCDFTemplate(...
    fullfile(path, [template '_attributes.txt']), sample_data, varIdx);
  
  % get qc flag values
  qcFlags = imosQCFlag('', sample_data.quality_control_set, 'values');
  qcDescs = {};
  
  % get flag descriptions
  for k = 1:length(qcFlags)
    qcDescs{k} = ...
      imosQCFlag(qcFlags(k), sample_data.quality_control_set, 'desc');
  end
  
  % if the flag values are characters, turn the flag values 
  % attribute into a string of comma separated characters
  if strcmp(netcdfType, 'char')
    qcFlags(2,:) = ',';
    qcFlags = reshape(qcFlags, 1, numel(qcFlags));
    qcFlags = qcFlags(1:end-1);
    qcFlags = strrep(qcFlags, ',', ', ');
  end
  qcAtts.flag_values = qcFlags;
  
  % turn descriptions into space separated string
  qcDescs = cellfun(@(x)(sprintf('%s ', x)), qcDescs, 'UniformOutput', false);
  qcAtts.flag_meanings = [qcDescs{:}];
  
  vid = netcdf.defVar(fid, varname, netcdfType, dims);
  putAtts(fid, vid, var, qcAtts, template, netcdfType, dateFmt, '');
end

function putAtts(fid, vid, var, template, templateFile, netcdfType, dateFmt, mode)
%PUTATTS Puts all the attributes from the given template into the given NetCDF
% variable.
%
% This code is repeated a number of times, so it made sense to enclose it in a
% separate function. Takes all the fields from the given template struct, and 
% writes them to the NetCDF file specified by fid, in the variable specified by
% vid.
%
% Inputs:
%   fid          - NetCDF file identifier
%   vid          - NetCDF variable identifier
%   var          - NetCDF variable/dimension
%   template     - Struct containing attribute names/values.
%   templateFile - name of the template file from where the attributes
%                  originated.
%   netcdfType   - type to use for casting valid_min/valid_max/_FillValue attributes.
%   dateFmt      - format to use for writing date attributes.
%   mode         - Toolbox data type mode ('profile' or 'timeSeries').
%  

  % we convert the NetCDF required data type into a casting function towards the
  % appropriate Matlab data type
  qcSet   = str2double(readProperty('toolbox.qc_set'));
  qcType  = imosQCFlag('', qcSet, 'type');
  typeCastFunction = str2func(netcdf3ToMatlabType(netcdfType));
  qcTypeCastFunction = str2func(netcdf3ToMatlabType(qcType));

  % each att is a struct field
  atts = fieldnames(template);
  for k = 1:length(atts)

    name = atts{k};
    val  = template.(name);
    
    if isempty(val), continue; end;
    
    type = 'S';
    try, type = templateType(name, templateFile, mode);
    catch e, end
    
    switch type
      case 'D', val = datestr(val, dateFmt);
    end
    
    % matlab-no-support-leading-underscore kludge
    if name(end) == '_', name = ['_' name(1:end-1)]; end
    
    if any(strcmpi(name, {'valid_min', 'valid_max', '_FillValue', 'flag_values'}))
        val = typeCastFunction(val);
    end
    
    if strcmpi(name, 'quality_control_indicator') && isfield(var, 'flags')
        % if all flag values are equal, add the 
        % quality_control_indicator attribute
        minFlag = min(var.flags(:));
        maxFlag = max(var.flags(:));
        if minFlag == maxFlag
            val = minFlag;
        end
        val = qcTypeCastFunction(val);
    end
    
    % add the attribute
    %disp(['  ' name ': ' val]);
    netcdf.putAtt(fid, vid, name, val);
  end
end
