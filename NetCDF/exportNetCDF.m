function exportNetCDF( sample_data, cal_data, dest )
%EXPORTNETCDF Export the given sample and calibration data to a set of NetCDF
% files.
%
% Export the given sample and calibration data to a set of NetCDF files. The
% files asaved to the given destination directory. The files are named
% according to the IMOS file naming convention version 1.1.
%
% Inputs:
%   sample_data - a row vector of structs, each element containing sample data
%                 for one process level.
%
%   cal_data    - a struct containing calibration and metadata.
%
%   dest        - Destination directory to save the files.
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
error(nargchk(3, 3, nargin));

if ~isvector(sample_data), error('sample_data must be a vector of structs'); end
if ~isstruct(sample_data), error('sample_data must contain structs');        end
if ~isstruct(cal_data),    error('cal_data must be a struct');               end
if ~ischar(dest),          error('dest must be a string');                   end

% check that destination is a directory
[stat atts] = fileattrib(dest);
if ~stat || ~atts.directory || ~atts.UserWrite
  error([dest ' does not exist, is not a directory, or is not writeable']);
end


% a separate file is created for each sample_data struct 
% (each struct corresponds to one process level)
for k = 1:length(sample_data)
  
  % get an appropriate filename
  filename = genFileName(sample_data(k), cal_data);
  disp(['creating ' filename]);
  
  fid = netcdf.create(filename, 'NC_NOCLOBBER');
  
  %
  % the file is created in the following order
  %
  % 1. global attributes
  % 2. dimensions
  % 3. variable definitions
  % 4. data
  % 
  globConst = netcdf.getConstant('NC_GLOBAL');
  
  netcdf.putAtt(fid, globConst, 'name', 'val');
  
end

function filename = genFileName(sample_data, cal_data)
%GENFILENAME Generate an IMOS compliant NetCDF file name for the given data set.
%
% Generates an IMOS compliant file name for the given data set. See the IMOS
% NetCDF File Naming Convention document.
%
% Inputs:
%   sample_data - Single struct containing sample data.
%
%   cal_data    - struct containing calibration and metadata.
%
% Outputs:
%   filename    - an IMOS compliant filename.
%
error(nargchk(2,2,nargin));

if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isstruct(cal_data),    error('cal_data must be a struct');    end

%
% get all the individual components that make up the filename
%
% all date fields are in ISO 8601 format, which is specified 
% by passing the  code '30' to the datestr function
%
facility_code = 'facility-code';
data_code     = 'data-code';
start_date    = datestr(sample_data.dimensions.time(1), 30);
platform_code = 'platform-code';
file_version  = ['FV0' num2str(sample_data.level)];
product_type  = 'product-type';
end_date      = datestr(sample_data.dimensions.time(end), 30);
creation_date = datestr(now(), 30);

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
