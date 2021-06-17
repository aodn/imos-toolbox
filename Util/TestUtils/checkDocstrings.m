function [ok, wrong_files, nfiles, error_msgs, missing_comment, missing_example] = checkDocstrings(folder)
% function [ok, wrong_files, nfiles, error_msgs, missing_comment, missing_example] = checkDocstrings(folder)
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
% nfiles - The total number of files tested.
% error_msgs - the msg triggered by the test evaluation.
% missing_comment - A cell with files that are missing comments.
% missing_example - A cell with files that are missing the Example
%                  block from the toolbox docstring standard.
%
% Example:
%
% folder = [toolboxRootPath 'Util/TestUtils']
% [ok,wrong_files] = checkDocstrings(folder);
% assert(ok)
% assert(isempty(wrong_files));
% assert(false)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)
wrong_files = {};

files = rdir(folder);
if isempty(files)
	errormsg('No files present at %s folder',folder)
end

xunit_folder = fullfile(toolboxRootPath(),'test');
not_a_xunit_test = @(x)(~contains(x,xunit_folder));
non_xunit_tests = cellfun(not_a_xunit_test,files);
files = files(non_xunit_tests);

srcfiles = cell2mat(cellfun(@is_matlab,files,'UniformOutput',false));
matlab_files = files(srcfiles);
self_calling = contains(matlab_files,'checkDocstrings');
if any(self_calling)
	matlab_files(self_calling) = [];
end
nfiles = numel(matlab_files);
oks = zeros(1,nfiles);
msgs = cell(1,nfiles);
for k=1:numel(matlab_files)
	file = matlab_files{k};
	fprintf('%s: checking %s\n',mfilename,file)
	[oks(k),msgs{k}] = testDocstring(file);
end

if all(oks)
	ok = true;
else
	ok = false;
end

if nargout > 1
	wrong_files = matlab_files(~oks);
end

if nargout > 2
	error_msgs = msgs(~oks);
end

if nargout > 3
    check_comment = @(x)(contains(x,'No docstring block found in '));
    lack_comment = cellfun(check_comment,msgs);
    missing_comment = matlab_files(lack_comment);
end

if nargout > 4
    check_example = @(x)(contains(x,'No docstring Example block found in '));
    lack_example = cellfun(check_example,msgs);
    missing_example = matlab_files(lack_example);
end

end

function is_matlab = is_matlab(filestr)
	[~,~,ext] = fileparts(filestr);
	is_matlab = strcmp(ext,'.m');
end
