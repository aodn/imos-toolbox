function [header_info] = translateHeaderText(header_content, header_rules)
% function [header_info] = translateheadertext(header_content,header_rules)
%
% Translate content based on rules.
%
% Inputs:
%
% header_content - A cell containings tructures with:
%               .key - a string repr of the line key*name
%               .value - a string of representing the line value
% header_rules - A struct of structs. Fieldnames are rule names.
%             .(rule) - the rule structure.
%             .(rule).fun - a function that accept arguments.
%             .(rule).args - a cell with argument names
%             .(rule).args{1} = a string matching a key*name.
%
% Outputs:
%
% header_info - a Structure with rule as fieldnames and values
%               as the result of the fun(args{:})
%
% Example:
% header_kv = {struct('key','x','value','y')};
% rules.is_x_value_a_numeric = struct('args',{{'x'}},'fun',@isnumeric);
% [z] = translateHeaderText(header_kv,rules);
% assert(z.is_x_value_a_numeric==false);
%
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) , Australian Ocean Data Network (AODN) and Integrated
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

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.

if nargin < 2
    error('Need a valid rule struct')
end

if isAnyCellItemEmpty(header_content)
    error('Header content is empty. Check your rules.')
end

header_info = struct();
ni = length(header_content);
hnames = cell(1, ni);

for n = 1:ni
    hnames{n} = header_content{n}.('key');
end

rule_names = fieldnames(header_rules);
nrules = length(rule_names);

for n = 1:nrules
    rule_name = rule_names{n};
    func = header_rules.(rule_name).('fun');
    req_args = header_rules.(rule_name).('args');
    [~, indexes] = inCellPartialMatch(hnames, req_args);

    if numel(indexes) > 0
        nindexes = length(indexes);
        args = cell(1, nindexes);

        for k = 1:nindexes
            args{k} = header_content{indexes(k)}.value;
        end

        header_info.(rule_name) = func(args{:});

    end

end

end
