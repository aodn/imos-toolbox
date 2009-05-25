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
  filename = genFileName(sample_data);
  filename = [dest filesep filename];
  
  disp(['creating ' filename]);
  fid = netcdf.create(filename, 'NC_NOCLOBBER');
  if fid == -1, error(['could not create ' filename]); end
  
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
    disp('writing global attributes');
    globAtts = sample_data;
    globAtts = rmfield(globAtts, 'variables');
    globAtts = rmfield(globAtts, 'dimensions');
    putAtts(fid, globConst, globAtts);

    %
    % dimension and coordinate variable definitions
    %
    dims = sample_data.dimensions;
    for m = 1:length(dims)

      disp(['creating dimension: ' dims{m}.name ...
            ' (length: ' num2str(length(dims{m}.data)) ')']);
          
      dimAtts = dims{m};
      dimAtts = rmfield(dimAtts, 'data');

      % create dimension
      did = netcdf.defDim(fid, upper(dims{m}.name), length(dims{m}.data));

      % temporarily save the netcdf dimension ID in 
      % the dimension struct for later reference
      sample_data.dimensions{m}.did = did;

      % create coordinate variable and attributes
      vid = netcdf.defVar(fid, upper(dims{m}.name), 'double', did);
      putAtts(fid, vid, dimAtts);
    end

    %
    % variable definitions
    %
    dims = sample_data.dimensions;
    vars = sample_data.variables;
    for m = 1:length(vars)

      varname = vars{m}.name;
      disp(['creating variable: ' varname]);
      
      % get the dimensions for this variable
      dids = [];
      dimIdxs = vars{m}.dimensions;
      for n = 1:length(dimIdxs), dids(n) = dims{dimIdxs(n)}.did; end
      
      % create the variable
      vid = netcdf.defVar(fid, varname, 'double', dids);

      varAtts = vars{m};
      varAtts = rmfield(varAtts, 'data');
      varAtts = rmfield(varAtts, 'dimensions');

      % add the attributes
      putAtts(fid, vid, varAtts);
    end

    % we're finished defining dimensionss/attributes/variables
    netcdf.endDef(fid);

    %
    % coordinate variable data
    %
    dims = sample_data.dimensions;
    for m = 1:length(dims)

      varname = dims{m}.name;
      vid     = dims{m}.did;
      data    = dims{m}.data;
      disp(['writing data: ' varname ' (length: ' num2str(length(data)) ')']);

      netcdf.putVar(fid, vid, data);
    end

    %
    % variable data
    %
    vars = sample_data.variables;
    for m = 1:length(vars)

      varname = vars{m}.name;
      data    = vars{m}.data;
      disp(['writing data: ' varname ' (length: ' num2str(length(data)) ')']);

      vid = netcdf.inqVarID(fid, varname);
      netcdf.putVar(fid, vid, data);
    end

    %
    % and we're done
    %
    netcdf.close(fid);
  
  % ensure that the file is closed in the event of an error
  catch e
    netcdf.close(fid);
    rethrow e;
  end
end

function filename = genFileName(sample_data)
%GENFILENAME Generate an IMOS compliant NetCDF file name for the given data set.
%
% Generates an IMOS compliant file name for the given data set. See the IMOS
% NetCDF File Naming Convention document.
%
% Inputs:
%   sample_data - Single struct containing sample data.
%
% Outputs:
%   filename    - an IMOS compliant filename.
%
  error(nargchk(1,1,nargin));

  if ~isstruct(sample_data), error('sample_data must be a struct'); end

  %
  % get all the individual components that make up the filename
  %

  file_version  = ['FV0' num2str(sample_data.level)];
  facility_code = sample_data.institution;
  platform_code = sample_data.platform_code;
  product_type  = '';

  %
  % all dates should be in ISO 8601 format
  %
  dateFmt       = readToolboxProperty('exportNetCDF.dateFormat');
  fileDateFmt   = readToolboxProperty('exportNetCDF.fileDateFormat');
  start_date    = ...
    datestr(datenum(sample_data.time_coverage_start, dateFmt), fileDateFmt);
  end_date      = ...
    datestr(datenum(sample_data.time_coverage_end, dateFmt),   fileDateFmt);
  creation_date = ...
    datestr(datenum(sample_data.date_created, dateFmt),        fileDateFmt);

  %
  % one data code for each parameter
  %
  data_code     = '';
  for k = 1:length(sample_data.variables)

    % get the data code for this parameter; don't add duplicate codes
    code = imosParameters(sample_data.variables{k}.name, 'data_code');
    if strfind(data_code, code), continue; end

    data_code(end+1) = code;
  end

  % build the file name
  filename = 'IMOS_';
  filename = [filename        facility_code '_'];
  filename = [filename        data_code     '_'];
  filename = [filename        start_date    '_'];
  filename = [filename        platform_code '_'];
  filename = [filename        file_version  '_'];
  filename = [filename        product_type  '_'];
  filename = [filename 'END-' end_date      '_'];
  filename = [filename 'C-'   creation_date '_'];
  filename = [filename '.nc'];

end

function putAtts(fid, vid, template)
%PUTATTS Puts all the attributes from the given template into the given NetCDF
% variable.
%
% This code is repeated a number of times, so it made sense to enclose it in a
% separate function. Takes all the fields from the given template struct, and 
% writes them to the NetCDF file specified by fid, in the variable specified by
% vid.
%
% Inputs:
%   fid      - NetCDF file identifier
%   vid      - NetCDF variable identifier
%   template - Struct containing attribute names/values.
%

  % each att is a struct field
  atts = fieldnames(template);
  for k = 1:length(atts)

    name = atts{k};
    val = template.(name);
    
    if isempty(val), continue; end;
    
    % matlab-no-support-leading-underscore kludge
    if name(end) == '_', name = ['_' name(1:end-1)]; end
    
    % add the attribute
    %disp(['  ' name ': ' val]);
    netcdf.putAtt(fid, vid, name, val);
  end
end
