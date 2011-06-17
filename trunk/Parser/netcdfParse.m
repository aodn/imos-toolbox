function sample_data = netcdfParse( filename )
%NETCDFPARSE Parses an IMOS NetCDF file.
%
% This function is able to import an IMOS compliant NetCDF file.
%
% Inputs:
%   filename    - cell array of file names (only one supported).
%
% Outputs:
%   sample_data - struct containing the imported data set.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor : Laurent Besnard <laurent.besnard@utas.edu.au>

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
  error(nargchk(1,1,nargin));

  if ~iscellstr(filename), error('filename must be a cell array of strings'); 
  end

  % only one input file supported
  filename = filename{1};
  
  % get date format for netcdf time attributes
  dateFmt = readProperty('exportNetCDF.dateFormat');

  ncid = netcdf.open(filename, 'NC_NOWRITE');
  
  globals    = [];
  dimensions = {};
  variables  = {};
  qcVars     = {};
  
  % get global attributes
  globals = readAtts(ncid, netcdf.getConstant('NC_GLOBAL'));
  
  % transform any time attributes into matlab serial dates
  timeAtts = {'date_created', 'time_coverage_start', 'time_coverage_end'};
  for k = 1:length(timeAtts)
    
    if isfield(globals, timeAtts{k})
      
      % Aargh, matlab is a steamer. Datenum cannot handle a trailing 'Z',
      % even though it's ISO8601 compliant. I hate you, matlab. Assuming 
      % knowledge of the date format here (dropping the last character).
      newTime = 0;
      try
        newTime = datenum(globals.(timeAtts{k}), dateFmt(1:end-1));
      
      % Glider NetCDF files use doubles for 
      % time_coverage_start and time_coverage_end
      catch e
        try newTime = globals.(timeAtts{k}) + datenum('1950-01-01 00:00:00');
        catch e
        end
      end
      globals.(timeAtts{k}) = newTime;
    end
  end
    
  % get dimensions
  k = 0;
  try
    while 1
      
      [name len] = netcdf.inqDim(ncid, k);
      
      % get id of associated coordinate variable
      varid = netcdf.inqVarID(ncid, name);
      
      dimensions{end+1} = readVar(ncid, varid);
      dimensions{end}   = rmfield(dimensions{end}, 'dimensions');
      
      k = k + 1;
    end
  catch e
  end
  
  % get variable data/attributes
  k = 0;
  try
    while 1
      
      v = readVar(ncid, k);
      
      k = k + 1;
      
      % skip coordinate variables - they have 
      % already been added as dimensions
      if getVar(dimensions, v.name) ~= 0, continue; end
      
      % update dimension IDs
      dims = v.dimensions;
      v.dimensions = [];
      for m = 1:length(dims)
        
        name = netcdf.inqDim(ncid, dims(m));
        v.dimensions(end+1) = getVar(dimensions, name);
      end
      
      % collate qc variables separately
      if strfind(v.name, '_quality_control'), qcVars   {end+1} = v;
      else                                    variables{end+1} = v;
      end
    end
  catch e
  end
  
  % add QC flags to dimensions
  for k = 1:length(dimensions)
    
    idx = getVar(qcVars, [dimensions{k}.name '_quality_control']);
    if idx == 0, continue; end
    dimensions{k}.flags = qcVars{idx}.data;
  end
  
  % and the same for the variables
  for k = 1:length(variables)
    
    idx = getVar(qcVars, [variables{k}.name '_quality_control']);
    if idx == 0, continue; end
    variables{k}.flags = qcVars{idx}.data;
  end
  
  netcdf.close(ncid);
  
  % offset time dimension - IMOS files store date as 
  % days since 1950; matlab stores as days since 0000
  time = getVar(dimensions, 'TIME');
  if time ~= 0
      dimensions{time}.data = ...
      dimensions{time}.data + datenum('1950-01-01 00:00:00');
  end
  
  % fill out the resulting struct
  sample_data            = globals;
  sample_data.dimensions = dimensions;
  sample_data.variables  = variables;
  
  sample_data.meta.instrument_make      = 'Unidata';
  sample_data.meta.instrument_model     = 'NetCDF';
  sample_data.meta.instrument_serial_no = '3.6';
  sample_data.meta.instrument_sample_interval = NaN;
  
  if isfield(sample_data, instrument_make)
      sample_data.meta.instrument_make = sample_data.instrument_make;
  end
  
  if isfield(sample_data, instrument_model)
      sample_data.meta.instrument_model = sample_data.instrument_model;
  end
  
  if isfield(sample_data, instrument_serial_no)
      sample_data.meta.instrument_serial_no = sample_data.instrument_serial_no;
  end
  
  if isfield(sample_data, instrument_sample_interval)
      sample_data.meta.instrument_sample_interval = sample_data.instrument_sample_interval;
  end
end

function v = readVar(ncid, varid)
%READVAR Creates a struct containing data for the given variable id.
%

  [name xtype dimids natts] = netcdf.inqVar(ncid, varid);

  v            = struct;
  v.name       = name;
  v.dimensions = dimids; % this is transformed below
  v.data       = netcdf.getVar(ncid, varid);
  
  % multi-dimensional data must be transformed, as matlab-netcdf api 
  % requires fastest changing dimension first, but toolbox requires
  % slowest changing dimension first
  nDims = length(v.dimensions);
  if nDims > 1, v.data = permute(v.data, nDims:-1:1); end

  % get variable attributes
  atts = readAtts(ncid, varid);
  attnames = fieldnames(atts);
  for k = 1:length(attnames), v.(attnames{k}) = atts.(attnames{k}); end
  
  % replace any fill values with matlab's nan
  if isfield(atts, 'FillValue_'), v.data(v.data == atts.FillValue_) = nan; end
end

function atts = readAtts(ncid, varid)
%READATTS Gets all of the NetCDF attributes from the given file/variable.
%
  atts = struct;
  k    = 0;

  try 
    while 1
      
      % inqAttName will throw an error when we run out of attributes
      name = netcdf.inqAttName(ncid, varid, k);
      sName = name;
      
      % no-leading-underscore kludge
      if sName(1) == '_', sName = [sName(2:end) '_']; end
      
      atts.(sName) = netcdf.getAtt(ncid, varid, name);
      k = k + 1;
      
    end
  catch e 
  end
end
