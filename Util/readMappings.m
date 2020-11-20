function [mappings] = readMappings(file, delimiter)
% function [mappings] = readMappings(file, delimiter)
%
% This read a simple mapping file,
% which is a two column delimited file.
% The first column of the file is a key,
% the second column is a value.
% The read ignores the `%` matlab comment
% symbol.
%
% Inputs:
%
% file [char] - a file path
% delimiter [char] - a field delimiter
%                    Default: ','
%
% Outputs:
%
% mappings - a containers.Map mapping
%
% Example:
%
% file = [toolboxRootPath 'GUI/instrumentAliases.txt'];
% [mappings] = readMappings(file)
% assert(mappings.Count>0)
% keys = mappings.keys;
% values = mappings.values;
% assert(ischar(keys{1}))
% assert(ischar(values{1}))
%
% author: hugo.oliveira@utas.edu.au
%
if nargin < 2
    delimiter = ',';
end

nf = fopen(file, 'r');
raw_read = textscan(nf, '%s', 'Delimiter', delimiter, 'CommentStyle', '%');
raw_read = raw_read{1};

try
    mappings = containers.Map(raw_read(1:2:end), raw_read(2:2:end));
catch
    error('Mapping file %s is incomplete.', file);
end
