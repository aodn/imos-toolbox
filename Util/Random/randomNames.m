function rnames = randomNames(n, len)
%function rnames = randomNames(n, len)
%
% Create `n` random names in a cell, where each
% name is `len` limited.
%
% Inputs:
%
%  n - the number of names to create
%  len - the length of each name
%
% Outputs:
%
%  rnames - 1xn cell with 1x[len] sized strings
%
% Example:
%
% rnames = randomNames(1);
% assert(iscell(rnames))
% assert(~isempty(rnames))
% assert(~isempty(rnames{1}))
% assert(isstr(rnames{1}))
%
% author: hugo.oliveira@utas.edu.au
%

if nargin < 1
    n = 1;
    len = 10;
elseif nargin < 2
    len = 10;
end

dict = '123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789abcdefghijklmnopqrstuvwxyz';
drange = [1, numel(dict)];
rnames = cell(1, n);

for k = 1:n
    rnames{k} = dict(randi(drange, 1, len));
end

end
