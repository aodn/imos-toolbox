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
narginchk(2,2);

if ~ischar(make),  error('make must be a string');  end
if ~ischar(model), error('model must be a string'); end

parser = 0;

path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'Parser');

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
