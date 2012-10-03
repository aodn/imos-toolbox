function sample_data = ECOTripletParse( filename, mode )
%ECOTripletParse parses a .RAW file retrieved from a Wetlabs ECO triplet instrument.
%
%
% Inputs:
%   filename    - name of the input file to be parsed
%   mode        - Toolbox data type mode ('profile' or 'timeSeries').
%
% Outputs:
%   sample_data - contains a time vector (in matlab numeric format), and a 
%                 vector of variable structs, containing sample data.
%                 
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%
% See http://www.wetlabs.com/products/eflcombo/triplet.htm
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
  % ensure that there is exactly one argument, 
  % and that it is a cell array of strings
  error(nargchk(1, 2, nargin));
  if ~iscell(filename), error('filename must be a cell array'); end

  filename = filename{1};
  if ~ischar(filename), error('filename must contain a string'); end

  [pathDirectory, devFilename, ext] = fileparts(filename);
  devFilename = fullfile(pathDirectory, [devFilename '.dev']);
  
  sample_data = [];
  
  if ~exist(devFilename, 'file'), error('device file must have the same name as the data file with .dev as an extension'); end
  
  deviceInfo = readECODevice(devFilename);
  
  sample_data = readECOraw(filename, deviceInfo);

end