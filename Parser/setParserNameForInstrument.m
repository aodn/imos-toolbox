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
