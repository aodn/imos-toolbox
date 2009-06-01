function filename = genNetCDFFileName( sample_data )
%GENNETCDFFILENAME Generates a NetCDF file name for the given data set.
%
% Generates a NetCDF file name for the given data set. The file name is
% geneated according to the IMOS NetCDF File Naming Convention, version
% 1.3.
%
% Inputs:
%   sample_data - the data set to generate a file name for.
%
% Outputs:
%   filename    - the generated file name.
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
