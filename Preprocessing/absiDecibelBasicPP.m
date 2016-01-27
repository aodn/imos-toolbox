function sample_data = absiDecibelBasicPP( sample_data, qcLevel, auto )
%ABSIDECIBELBASICPP derives ABSI from ABSIC applying an arbitrary coefficient.
%
% Derives acoustic backscatter intensity values in dB from values in counts by 
% multiplying by a coeficient (default 0.45).
% See http://www.nortek-as.com/en/knowledge-center/forum/velocimeters/577870840
% and http://www.nortek-as.com/lib/technical-notes/seditments .
%
% Inputs:
%   sample_data - cell array of structs. Includes ABSIC parameters.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, check if pre-processing in batch mode.
%
% Outputs:
%   sample_data - same as input, with data parameters ABSI derived from ABSIC.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  narginchk(2, 3);

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
   
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
  
  for k = 1:length(sample_data)
      
      absiAdded = false;
      
      sam = sample_data{k};
      
      % so far there is a maximum of 4 beams with ABSIC data for ADCPs
      for n = 1:4
          absicVarName = ['ABSIC' num2str(n)];
          absiVarName  = ['ABSI'  num2str(n)];
          absicIdx  = getVar(sam.variables, absicVarName);
          
          % dataset doesn't have ABSIC data
          if ~ absicIdx, continue; end
          
          % dataset already include ABSI data
          if getVar(sam.variables, absiVarName), continue; end
          
          absic = sam.variables{absicIdx}.data;
          
          coefFile = ['Preprocessing' filesep 'absiDecibelBasicPP.txt'];
          coefficient = str2double(readProperty('coefficient', coefFile));
          absi = absic * coefficient;
          
          dimensions = sam.variables{absicIdx}.dimensions;
          
          absiComment = ['absiDecibelBasicPP.m: ABSI derived from ABSIC values in unit count multiplied by ' num2str(coefficient) '.'];
          
          if isfield(sam.variables{absicIdx}, 'coordinates')
              coordinates = sam.variables{absicIdx}.coordinates;
          else
              coordinates = '';
          end
          
          % add ABSI data as new variable in data set
          sam = addVar(...
              sam, ...
              absiVarName, ...
              absi, ...
              dimensions, ...
              absiComment, ...
              coordinates);
          
          absiAdded = true;
      end
      
      if absiAdded
          sample_data{k} = sam;
          history = sample_data{k}.history;
          if isempty(history)
              sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), absiComment);
          else
              sample_data{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), absiComment);
          end
      end
  end