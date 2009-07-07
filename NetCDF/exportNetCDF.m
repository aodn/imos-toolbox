function filename = exportNetCDF( sample_data, dest )
%EXPORTNETCDF Export the given sample data to a NetCDF file.
%
% Export the given sample and calibration data to a NetCDF file. The file is 
% saved to the given destination directory. The file is named according to the 
% IMOS file naming convention version 1.1.
%
% Inputs:
%   sample_data - a struct containing sample data for one process level.
%
%   dest        - Destination directory to save the file.
%
% Outputs:
%   filename    - String containing the absolute path of the saved NetCDF file.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  error(nargchk(2, 2, nargin));

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
  
  dateFmt = readToolboxProperty('exportNetCDF.dateFormat');
  qcSet   = str2double(readToolboxProperty('toolbox.qc_set'));
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
    putAtts(fid, globConst, globAtts, 'global_attributes.txt', dateFmt);
    
    % if the QC flag values are characters, we must define 
    % a dimension to force the maximum value length to 1
    if strcmp(qcType, 'char')
      qcDimId = netcdf.defDim(fid, 'qcStrLen', 1);
    end

    %
    % dimension and coordinate variable definitions
    %
    dims = sample_data.dimensions;
    for m = 1:length(dims)
          
      dimAtts = dims{m};
      dimAtts = rmfield(dimAtts, 'data');
      dimAtts = rmfield(dimAtts, 'flags');
      
      % add the QC variable (defined below) 
      % to the ancillary variables attribute
      dimAtts.ancillary_variables = [dims{m}.name '_quality_control'];

      % create dimension
      did = netcdf.defDim(fid, upper(dims{m}.name), length(dims{m}.data));

      % create coordinate variable and attributes
      vid = netcdf.defVar(fid, upper(dims{m}.name), 'double', did);
      templateFile = [lower(dims{m}.name) '_attributes.txt'];
      putAtts(fid, vid, dimAtts, templateFile, dateFmt);
      
      % create the ancillary QC variable
      qcvid = addQCVar(...
        fid, sample_data, m, [qcDimId did], 'dim', qcType, dateFmt);
      
      % save the netcdf dimension and variable IDs 
      % in the dimension struct for later reference
      sample_data.dimensions{m}.did   = did;
      sample_data.dimensions{m}.vid   = vid;
      sample_data.dimensions{m}.qcvid = qcvid;
    end

    %
    % variable (and ancillary QC variable) definitions
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    for m = 1:length(vars)

      varname = vars{m}.name;
      
      % get the dimensions for this variable
      dids = [];
      dimIdxs = vars{m}.dimensions;
      for n = 1:length(dimIdxs), dids(n) = dims{dimIdxs(n)}.did; end
      
      % reverse dimension order - matlab netcdf.defvar requires 
      % dimensions in order of fastest changing to slowest changing. 
      % The time dimension is always first in the variable.dimensions 
      % list, and is always the slowest changing.
      dids = fliplr(dids);
      
      % create the variable
      vid = netcdf.defVar(fid, varname, 'double', dids);

      varAtts = vars{m};
      varAtts = rmfield(varAtts, 'data');
      varAtts = rmfield(varAtts, 'dimensions');
      varAtts = rmfield(varAtts, 'flags');
      
      % add the QC variable (defined below) 
      % to the ancillary variables attribute
      varAtts.ancillary_variables = [varname '_quality_control'];

      % add the attributes
      putAtts(fid, vid, varAtts, 'variable_attributes.txt', dateFmt);
      
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
    
    % translate time from matlab serial time (days since 0000-00-00 00:00:00Z)
    % to IMOS mandated time (days since 1950-01-01T00:00:00Z)
    if strcmpi(dims{1}.name, 'TIME')
      dims{1}.data = dims{1}.data - datenum('1950-01-00 00:00:00');
    end
    
    for m = 1:length(dims)
      
      % variable data
      vid     = dims{m}.vid;
      qcvid   = dims{m}.qcvid;
      data    = dims{m}.data;

      netcdf.putVar(fid, vid, data');
      
      % ancillary QC variable data
      data    = dims{m}.flags;
      
      netcdf.putVar(fid, qcvid, data);
    end

    %
    % variable (and ancillary variable) data
    %
    vars = sample_data.variables;
    for m = 1:length(vars)

      % variable data
      data    = vars{m}.data;
      vid     = vars{m}.vid;
      qcvid   = vars{m}.qcvid;
      
      % replace NaN's with fill value
      data(isnan(data)) = vars{m}.FillValue_;

      % transpose required, as matlab requires the fastest changing
      % dimension to be first. This code will fall over for data sets
      % of more than two dimensions.
      netcdf.putVar(fid, vid, data');
      
      % ancillary QC variable data
      data    = vars{m}.flags;
      
      netcdf.putVar(fid, qcvid, data');
    end

    %
    % and we're done
    %
    netcdf.close(fid);
  
  % ensure that the file is closed in the event of an error
  catch e
    try netcdf.close(fid); catch ex, end
    rethrow(e);
  end
end

function vid = addQCVar(...
  fid, sample_data, varIdx, dims, type, outputType, dateFmt)
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
%   outputType  - The matlab type in which the flags should be output.
%   dateFmt     - Date format in which date attributes should be output.
%
% Outputs:
%   vid         - NetCDF variable identifier of the QC variable that was 
%                 created.
%
  switch(type)
    case 'dim'
      var = sample_data.dimensions{varIdx};
      template = 'qc_coord_attributes.txt';
    case 'var'
      var = sample_data.variables{varIdx};
      template = 'qc_attributes.txt';
    otherwise
      error(['invalid type: ' type]);
  end
  
  path = [fileparts(which(mfilename)) filesep 'template' filesep];
  
  varname = [var.name '_quality_control'];
  
  qcAtts = parseNetCDFTemplate([path template], sample_data, varIdx);
  
  % get qc flag values
  qcFlags = imosQCFlag('', sample_data.quality_control_set, 'values');
  qcDescs = {};
  
  % get flag descriptions
  for k = 1:length(qcFlags)
    qcDescs{k} = ...
      imosQCFlag(qcFlags(k), sample_data.quality_control_set, 'desc');
  end
 
  % if all flag values are equal, add the 
  % quality_control_indicator attribute 
  minFlag = min(var.flags(:));
  maxFlag = max(var.flags(:));
  if minFlag == maxFlag
    if strcmp(outputType, 'char'), minFlag = char(minFlag); end
    qcAtts.quality_control_indicator = minFlag; 
  end
  
  % force fill value to correct type
  if strcmp(outputType, 'byte')
    qcAtts.FillValue_ = uint8(qcAtts.FillValue_);
  end
  
  % if the flag values are characters, turn the flag values 
  % attribute into a string of comma separated characters
  if strcmp(outputType, 'char')
    qcFlags(2,:) = ',';
    qcFlags = reshape(qcFlags, 1, numel(qcFlags));
    qcFlags = qcFlags(1:end-1);
    qcFlags = strrep(qcFlags, ',', ', ');
  end
  qcAtts.flag_values = qcFlags;
  
  % turn descriptions into space separated string
  qcDescs = cellfun(@(x)(sprintf('%s ', x)), qcDescs, 'UniformOutput', false);
  qcAtts.flag_meanings = [qcDescs{:}];
  
  vid = netcdf.defVar(fid, varname, outputType, dims);
  putAtts(fid, vid, qcAtts, template, dateFmt);
end

function putAtts(fid, vid, template, templateFile, dateFmt)
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
%   template     - Struct containing attribute names/values.
%   templateFile - name of the template file from where the attributes
%                  originated.
%   dateFmt      - format to use for writing date attributes.
%  

  % each att is a struct field
  atts = fieldnames(template);
  for k = 1:length(atts)

    name = atts{k};
    val  = template.(name);
    
    if isempty(val), continue; end;
    
    type = templateType(name, templateFile);
    
    switch type
      case 'D', val = datestr(val, dateFmt);
    end
    
    % matlab-no-support-leading-underscore kludge
    if name(end) == '_', name = ['_' name(1:end-1)]; end
    
    % add the attribute
    %disp(['  ' name ': ' val]);
    netcdf.putAtt(fid, vid, name, val);
  end
end
