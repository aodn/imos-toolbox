function values = imosQCTests()
%imosQCTests Returns a 1x2 cell array reading the info found in
%ImosQCTests.txt
%  - the first one contains a list of QC routines
%  - the second cell returns a positional integer for each routine
%
% Inputs:
%
%   N.A.
%
% Outputs:
%   1x2 cell array 
%
% Author:       Laurent Besnard <laurent.besnard@utas.edu.au>
%

%
% Copyright (C) 2023, Australian Ocean Data Network (AODN) and Integrated 
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

% open the IMOSQCFTests file - it should be 
% in the same directory as this m-file
path = '';
if ~isdeployed, [path, ~, ~] = fileparts(which('imosToolbox.m')); end
if isempty(path), path = pwd; end
path = fullfile(path, 'IMOS');

fidS = -1;
try
  % read in the QC sets
  fidS = fopen([path filesep 'imosQCTests.txt'], 'rt');
  if fidS == -1, return; end
  sets  = textscan(fidS, '%s%f', 'delimiter', ',', 'commentStyle', '%');
  fclose(fidS);
  
  %  rewrite sets with correct qc flag test values using the imosQCTest
  %  function
  nQcFlags = length(sets{1});
  for k = 1:nQcFlags
    sets{1,2}(k) = imosQCTest(sets{1,1}{k});
  end
  
  values = sets;
    
catch e
  if fidS ~= -1, fclose(fidS); end
  rethrow(e);
end


