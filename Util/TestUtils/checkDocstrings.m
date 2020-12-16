function [ok, wrong_files] = checkDocstrings(folder)
% function [ok, wrong_files] = checkDocstrings(folder)
%
% Check all matlab source file IMOS docstrings in a folder.
%
% Inputs:
% 
% folder [str] - a string with the folder location.
%
% Outputs:
% 
% ok [bool] - All docstrings are fine.
% wrong_files - A cell where the evaluation of the docstring failed.
%
% Example:
%
% folder = [toolboxRootPath 'Util/TestUtils']
% [ok,wrong_files] = checkDocstrings(folder);
% assert(ok)
% assert(isempty(wrong_files));
%
% author: hugo.oliveira@utas.edu.au
%
ok = false;
wrong_files = {};

files = rdir(folder);
if isempty(files)
	errormsg('No files present at %s folder',folder)
end

srcfiles = cell2mat(cellfun(@is_matlab,files,'UniformOutput',false));
matlab_files = files(srcfiles);
self_calling = contains(matlab_files,'checkDocstrings');
if any(self_calling)
	matlab_files(self_calling) = [];
end
nfiles = numel(matlab_files);

oks = zeros(1,nfiles);
for k=1:nfiles
	file = matlab_files{k};
	fprintf('%s: checking %s\n',mfilename,file)
	[oks(k),~] = testDocstring(file);
end

if all(oks)
	ok = true;
end

report = nargout>1 && failed;
if report
	wrong_files = matlab_files(~oks);
end

end

function is_matlab = is_matlab(filestr)
	[~,~,ext] = fileparts(filestr);
	is_matlab = strcmp(ext,'.m');
end
