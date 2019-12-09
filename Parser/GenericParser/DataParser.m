function [rawdata, data] = DataParser(fid, sdata)
% function [rawdata,data] = DataParser(fid,sdata)
%
% A wrapper function to parse data from a
% file id with a pre-defined super data structure.
% See Parsers and rules.
%
% Inputs:
%
% fid - The file id.
% sdata - The super data structure that
%         declare how to read that type of file.
%
% Outputs:
%
% rawdata - the raw data structure as read from the file
% data - the data structure processed by the control rules in sdata.
%
% Example:
% % See any modern Parser in the GenericParser folder
% % for complex/simple cases.
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%

narginchk(2, 2)

if ~isnumeric(fid)
    error('first argument should be a file id numeric')
elseif ~isstruct(sdata)
    error('second argument should be a structure')
end

check_sdata(sdata);
rawdata = readColumnarData(fid, sdata.header_info, sdata.data_def_rules);
data = TransformData(rawdata, sdata);

end

function [rawdata] = readColumnarData(fid, header_info, data_def_rules)
% function [rawdata] = readColumnarData(fid, header_info, data_def_rules)
%
% An internal function to read Columnar data given
% a file id, header_info[rmation] and some definition rules.
%
% Inputs:
%
% fid - The file id.
% header_info - the header field struture
% data_def_rules - the rules to read the data.
%
% sdata - The super data structure that
%         declare how to read that type of file.
%
% Outputs:
%
% rawdata - the raw data structure as read from the file
% data - the data structure processed by the control rules in sdata.
%
% Example:
% % See any modern Parser in the GenericParser folder
% % for complex/simple cases.
%
% author: hugo.oliveira@utas.edu.au
%
rfun = data_def_rules.func;
rfun_aux_args = data_def_rules.key_value_signature(header_info);
rawdata = rfun(fid, rfun_aux_args{:});

end

function [data] = TransformData(rawdata, sdata)
% function [data] = TransformData(rawdata, sdata)
%
% Transform the data according to oper rules and
% header_information fields.
%
% Inputs:
%
% rawdata - a cell with the raw data loaded.
% sdata - The super data structure that
%         declare how to read that type of file.
%
% Outputs:
%
% data - The rawdata transformed.
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(2, 2)
obj = struct();
obj.rawdata = rawdata;
obj.header_info = sdata.header_info;
obj.data_oper_rules = sdata.data_oper_rules;

ndata = numel(obj.rawdata);
data_order = fieldnames(obj.data_oper_rules);
nrules = numel(data_order);

if ndata > nrules
    warning('Got %d columns but only %d rules to read then', ndata, nrules);
end

for n = 1:ndata
    name = data_order{n};
    arglist = obj.data_oper_rules.(name).args;
    fun = obj.data_oper_rules.(name).fun;
    no_args = isempty(arglist);

    if no_args
        data.(name) = fun();
    else
        %find arguments at root level of obj or within header_info.
        args1 = fields2cell(obj, arglist);
        args2 = fields2cell(obj.header_info, arglist);
        args = fillEmptyCellIndex(args1, args2);
        [missing_args, list_of_missing] = inCell(args, cell(0, 0));

        if missing_args
            raise_missing_argument(name, arglist, list_of_missing);
        else
            data.(name) = fun(args{:});
        end

    end

end

end

function check_sdata(sdata)
% function check_sdata(sdata)
%
% Just check if the structure contains
% compulsory fields.
%
% Inputs:
%
% sdata - The super data structure that
%         declare how to read that type of file.
%
%
% author: hugo.oliveira@utas.edu.au
%

sfields = fieldnames(sdata);
no_header_info = ~inCell(sfields, 'header_info');

if no_header_info
    error('No header information');
end

no_data_def_rules = ~inCell(sfields, 'data_def_rules');

if no_data_def_rules
    error('No rules for data reading');
end

no_data_oper_rules = ~inCell(sfields, 'data_oper_rules');

if no_data_oper_rules
    error('No rules for data operation');
end

end

function raise_missing_argument(name, arglist, list_of_missing)
% function raise_missing_argument(name, arglist, list_of_missing)
%
% Custom raise error to report missing arguments
%
% Inputs:
%
% name - a string representing the data field.
% arglist - a cell with all arguments to obtain the data.
% list_of_missing - a cell all missing arguments to obtain the data.
%
%
% author: hugo.oliveira@utas.edu.au
%

mstr = '';

for k = 1:length(list_of_missing)
    mstr = strcat(mstr, ',', arglist{k});
end

error('Could not find arguments %s for data/rule %s', mstr, name);
end
