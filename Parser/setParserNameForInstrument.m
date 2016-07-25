function setParserNameForInstrument( make, model, parser )
%SETPARSERNAMEFORINSTRUMENT Saves the given parser-instrument mapping.
%
% The file instruments.txt contains mappings between instrument
% makes/models and the corresponding parsers to use. This function allows you 
% to add new mappings. Given an instrument make/model and a parser, it will
% save that mapping to instruments.txt.
%
% The parser functions are named in the format '[name]Parse' - this
% function requires the '[name]' element of the parser function name.
%
% Inputs:
%   make   - Instrument make.
%   model  - Instrument model.
%   parser - Parser name
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
narginchk(3,3);

if ~ischar(make),   error('make must be a string');   end
if ~ischar(model),  error('model must be a string');  end
if ~ischar(parser), error('parser must be a string'); end

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'Parser');

fid = -1;
try
  
  % open the file
  fid = fopen([path filesep 'instruments.txt'], 'at');
  if fid == -1, error('could not open instruments.txt'); end
  
  % append the new entry to the end of the file
  fprintf(fid, '%s, %s, %s\n', make, model, parser);
  
  fclose(fid);
catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e); 
end
