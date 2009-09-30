function parser = getParserNameForInstrument( make, model )
%GETPARSERNAMEFORINSTRUMENT Returns a parser to use for the given instrument
% make/model.
%
% The file instruments.txt contains mappings between instrument
% makes/models and the corresponding parsers to use. This function is just
% a front end to the file. Given an instrument make/model, it will return
% the name of the parser to use.
%
% The parser functions are named in the format '[name]Parse' - this
% function just returns the '[name]' element of the parser function name.
%
% Inputs:
%   make   - Instrument make.
%   model  - Instrument model.
%
% Outputs:
%   parser - name of parser to use, or 0 if there is no parser listed for the 
%            given make/model.
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
error(nargchk(2,2,nargin));

if ~ischar(make),  error('make must be a string');  end
if ~ischar(model), error('model must be a string'); end

parser = 0;

path = [pwd filesep 'Parser'];

% read in all the lines of the file
lines = {};
fid = -1;
try
  fid = fopen([path filesep 'instruments.txt'], 'rt');
  if fid == -1, error('could not open instruments.txt'); end
  lines = textscan(fid, '%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e); 
end

makes   = lines{1};
models  = lines{2};
parsers = lines{3};

% search for a make/model match
for k = 1:length(makes)
  
  if strcmpi(makes{k},  make) && strcmpi(models(k), model)
    parser = parsers{k};
    return;
  end
end
