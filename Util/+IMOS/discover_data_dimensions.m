function discovered_indexes = discover_data_dimensions(tdata, tdims)
% function [discovered_indexes] = discover_data_dimensions(tdata,tdims)
%
% Discover the respective dimensional indexes
% of a data array based on available IMOS toolbox dimensions.
% The function ignores the singleton dimensions.
%
% Inputs:
%
% tdata [array] - A nd-array.
% tdims [cell[struct]] - the IMOS toolbox dimensions cell.
%
% Outputs:
%
% discovered_indexes [array] - The cell indexes of the dimensions
%                              in tdims which match the size of tdata.
%
% Example:
%
% %basic
% a = zeros(5,1);
% b = IMOS.gen_dimensions('timeSeries',1,{'TIME'},{@single},{[1:5]'});
% assert(IMOS.discover_data_dimensions(a,b)==1)
%
% %extended
% a = zeros(5,10);
% b = IMOS.gen_dimensions('timeSeries',3,{},{},{[1:3]',[1:5]',[1:10]'});
% assert(all(IMOS.discover_data_dimensions(a,b)==[2,3]))
%
% %fails for row vectors
% a=zeros(2,1);
% b={};
% f=false;try;IMOS.discover_data_dimensions(a,b);catch;f=true;end
% assert(f)
%
% %duplicated dimensions can't be discovered.
% a = zeros(2,1);
% b = IMOS.gen_dimensions('timeSeries',2,{},{},{[1:3]',[1:3]'});
% try;IMOS.discover_data_dimensions(a,b);catch;r=true;end
% assert(r)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2);

if ~isnumeric(tdata) && ~iscell(tdata)
    errormsg('First argument `tdata` is not a data array or cell')
elseif ~iscellstruct(tdims)
    errormsg('Second argument `tdims` is not a cell of structs')
end

if isempty(tdata)
    discovered_indexes = [];
    return
end

available_dims_names = IMOS.get(tdims, 'name');
available_dims_len = IMOS.get_data_numel(tdims);
available_dims_len_as_array = cell2mat(available_dims_len);

tdata_size = size(tdata);
non_singleton_var_dims_len = removeSingleton(tdata_size);
[discovered_indexes] = whereincell(available_dims_len, num2cell(non_singleton_var_dims_len));

try
    invalid_discovery = ~isequal(numel(tdata), prod(available_dims_len_as_array(discovered_indexes)));
catch
    invalid_discovery = true;
end

if invalid_discovery
    missing_dims_len = setdiff(non_singleton_var_dims_len, available_dims_len_as_array);
    mfmt = repmat('%d ', 1, numel(missing_dims_len));
    errormsg(['Provided `data` contains undefined dimensions of length(s): [ ' mfmt '].'], missing_dims_len);
end

repeats = allrepeats(available_dims_len_as_array);
discovered_are_repeats = any(ismember(repeats, discovered_indexes));

if discovered_are_repeats
    blame_names = available_dims_names(repeats);
    blame_lens = available_dims_len(repeats);
    dfmt = repmat('%d,', 1, numel(tdata_size));
    dfmt = dfmt(1:end - 1);
    nfmt = repmat('%s[%d], ', 1, numel(blame_names));
    nfmt = nfmt(1:end - 1);
    eargs = cat(2, num2cell(tdata_size), squashCells(blame_names, blame_lens));
    errormsg(['Impossible dimensional discovery for `data` with size=[' dfmt ']. Dimensions ' nfmt ' are of the same length.'], eargs{:})
end

incomplete_discovery = ~isequal(numel(discovered_indexes), numel(non_singleton_var_dims_len));

if incomplete_discovery
    discovered_indexes = [];
end

end
