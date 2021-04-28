function [delimiter] = detectMappingDelimiter(fname)
% function [delimiter] = detectMappingDelimiter(fname)
%
% A simple delimiter detection for toolbox mapping/Property files.
%
% Inputs:
%
% fname - the text file.
%
% Outputs:
%
% delimiter - The delimiter used.
%
% Example:
%
% %basic usage
% comma_file = [toolboxRootPath 'GUI/instrumentAliases.txt'];
% assert(isequal(detectMappingDelimiter(comma_file),','))
% equal_file = [toolboxRootPath 'AutomaticQC/imosEchoIntensityQC.txt'];
% assert(isequal(detectMappingDelimiter(equal_file),'='))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)

delimiter = '';
comma_ok = false;
equal_ok = false;
if ~exist(fname,'file')
	errormsg('%s doesn''t exist.',fname)
end


try
	comma_opts = readMappings(fname,',');
	comma_ok = true;
catch
end

try 
	equal_opts = readMappings(fname,'=');
	equal_ok = true;
catch
end

if comma_ok && equal_ok
	if all(contains(comma_opts.keys,'='))
		delimiter = '=';
	elseif all(contains(equal_opts.keys,','))
		delimiter = ',';
	end
	return
elseif comma_ok
	delimiter = ',';
elseif equal_ok 
	delimiter = '=';
end

end
