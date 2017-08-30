function sample_data = WQMParse( filename, mode )
%WQMParse parses a .RAW or .DAT file retrieved from a Wetlabs WQM instrument.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode.
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of up to nine variable structs, containing sample 
%                 data.
%                 
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  % ensure that there is exactly one argument, 
  % and that it is a cell array of strings
  narginchk(1, 2);
  if ~iscell(filename), error('filename must be a cell array'); end

  filename = filename{1};
  if ~ischar(filename), error('filename must contain a string'); end

  [~, ~, ext] = fileparts(filename);
  
  sample_data = [];
  
  switch upper(ext)
      case '.DAT'
          sample_data = readWQMdat(filename, mode);
          
      case '.RAW'
          sample_data = readWQMraw(filename, mode);
          
      otherwise
          error('filename must either be a .DAT or .RAW WQM file')
  end
end