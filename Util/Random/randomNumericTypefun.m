function rntype = randomNumericTypefun(n)
%function rntype= randomNumericTypefun(n)
%
% Create `n` random numeric function handles in a cell.
%
% Inputs:
%
%  n - the number of names to create
%
% Outputs:
%
%  rntype - 1xn cell with random numerical function handle types
%
% Example:
%
% rntype = randomNumericTypefun(1);
% assert(length(rntype)==1);
% assert(isfunctionhandle(rntype{1}));
%
% author: hugo.oliveira@utas.edu.au
%
if nargin < 1
    n = 1;
end

dict = {@uint8, @uint16, @uint32, @uint64, @int8, @int16, @int32, @int64, @single, @double, @logical};
drange = [1, numel(dict)];
rntype = cell(1, n);

for k = 1:n
    rntype{k} = dict{randi(drange)};
end

end
