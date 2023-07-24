function value = imosQCTest( testName )
%imosQCTest Returns an appropriate QC flag_value (integer)
% given a qc test routine (String)

% The value returned by this function is the power of 2 of the qc routine
% positional integer available in imosQCTests.txt. This is used to store
% information in a variable in the form of integers
%
%
% Inputs:
%
%   testName - name of QC test
%
% Outputs:
%   value    - integer
%
% Author:       Laurent Besnard <laurent.besnard@utas.edu.au>
%
% Example:
%
% value = imosQCTest( 'userManualQC');
%
% 
% assert(value==2) 
%

narginchk(1, 1);
if ~ischar(testName),      error('field must be a string');              end

value = '';

% open the IMOSQCFTests.txt file - it should be 
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
  
  [~, idx] = ismember(testName, sets{1,1});
  
  value = int32(2^sets{1,2}(idx));  % return the 
    

catch e
  if fidS ~= -1, fclose(fidS); end
  rethrow(e);
end


