function [opts] = function_parameters()
% function [opts] = function_parameters()
%
% Load the current function parameters
% This typically involve loading a txt file with
% the same name as the running function, and
% converting the arguments.
%
% Inputs:
%
%
% Outputs:
%
% opts - the options loaded as map, converted
%        to numbers of a number.
%
% Example:
% %see imosSurfaceDetectionQC.m
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(0, 0)
opts = containers.Map();

called_by_function = callerName();
if isempty(called_by_function)
    return
end
fpath = which(called_by_function);
[folder, fname] = fileparts(fpath);
ofile_path = [fullfile(folder, fname) '.txt'];

missing_file = ~exist(ofile_path, 'file');
if missing_file
    return
end

delimiter = detectMappingDelimiter(ofile_path);
opts = readMappings(ofile_path,delimiter);
keys = opts.keys;

for k = 1:numel(keys)
    name = keys{k};
    nvalue = str2double(opts(name));

    if strcmpi(opts(name), 'nan') || ~isnan(nvalue)
        opts(name) = nvalue;
    end

end

end
