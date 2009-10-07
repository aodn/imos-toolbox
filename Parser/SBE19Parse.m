function sample_data = SBE19Parse( filename )
%SBE19PARSE Parses a converted (.cnv) data file from a Seabird SBE19plus V2 
% CTD recorder.
%
% This function is able to read in a converted (.cnv) data file retrieved 
% from a Seabird SBE19plus V2 CTD recorder. 
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%
% Outputs:
%   sample_data - Struct containing sample data.
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

  if ~iscellstr(filename)
    error('filename must be a cell array of strings'); 
  end

  % only one file supported currently
  filename = filename{1};
  
  % read in the file
  [instHeader fileHeader data] = readSBECNV(filename);
  
  % create sample data struct
  sample_data = struct;
  
  sample_data.meta.instrument_make = 'Seabird';
  if isfield(instHeader, 'instrument_model')
    sample_data.meta.instrument_model = instHeader.instrument_model;
  else
    sample_data.meta.instrument_model = 'SBE19';
  end
  
  if isfield(instHeader, 'instrument_firmware')
    sample_data.meta.instrument_firmware = instHeader.instrument_firmware;
  else
    sample_data.meta.instrument_firmware = '0';
  end
  
  if isfield(instHeader, 'instrument_serial_no')
    sample_data.meta.instrument_serial_no = instHeader.instrument_serial_no;
  else
    sample_data.meta.instrument_serial_no = '0';
  end
  
  sample_data.dimensions = {};  
  sample_data.variables  = {};
  
  % assume that there will always be a TIME field 
  sample_data.dimensions{1}.name = 'TIME';
  sample_data.dimensions{1}.data = data.TIME;
  
  % scan through the list of parameters that were read 
  % from the file, and create a variable for each
  vars = fieldnames(data);
  for k = 1:length(vars)
    
    if (strncmp(vars{k}, 'TIME', 4)), continue; end
      
    sample_data.variables{end+1}.dimensions = [1];
    sample_data.variables{end  }.name       = vars{k};
    sample_data.variables{end  }.data       = data.(vars{k});
  end
end
