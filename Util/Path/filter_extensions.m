function [clean,removed] = filter_extensions(filenames,extensions)
% function [clean,removed] = filter_(filenames)
%
% Given a cell, filter out file names with certain
% extensions.
%
% Inputs:
%
% filenames[cell] - cell of file names
% extensions[cell] - cell of file extensions
%
% Outputs:
%
% filtered - the filtered cell
% removed - the members left out
%
% Example:
%
% %basic usage
% files = {'a.m','b.txt','c.mat','d.log','e.nc'};
% x = filter_extensions(files,'.mat');
% assert(~inCell(x,'c.mat'))
% x = filter_extensions(files,'.m');
% assert(~inCell(x,'a.m'))
% x = filter_extensions(files,{'.m','.txt','.mat','.nc'});
% assert(isequal(x,{'d.log'}))
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2,2)
if ~iscellstr(filenames)
	errormsg('First argument is not a cell of strings')
elseif ~ischar(extensions) && ~iscellstr(extensions)
	errormsg('Second argument is not a cell of strings')
end

if ischar(extensions)
	extensions={extensions};
end


nf = numel(filenames);
clean = cell(1,nf);
removed = cell(1,nf);

cc=0;
cr=0;
for k=1:numel(filenames)
	file = filenames{k};
	[~,~,ext] = fileparts(file);
	if inCell(extensions,ext)
		cr=cr+1;
		removed{cr} = file;
	else
		cc=cc+1;
		clean{cc} = file;
	end
end

removed=removed(1:cr);
clean=clean(1:cc);

end
