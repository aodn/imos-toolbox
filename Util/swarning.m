function swarning(varargin)
    % function swarning(varargin)
    %
    % Return a better swarninging message,
    % with stack traces messages similar to error.
    %
    % Mostly useful within functions,subfunctions
    % and deeper scopes.
    %
    % Inputs:
    %
    % varargin - arguments to sprintf
    %
    % Example:
    % print current scope with the swarninging msg
    % swarning('Something to be aware of: 1+1=',2)
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
    if nargin == 0
        swarning('Not enough input arguments');
    end

    error_in_args = false;
    st = dbstack;

    try
        testmsg = sprintf(varargin{:});
    catch emsg
        error_in_args = true;
        newentry.file = 'sprintf.m';
        newentry.name = 'sprintf';
        newentry.line = 1.00;
        st(end + 1) = newentry;
    end

    scope_level = numel(st);
    if scope_level == 0
        msg = ['Warning: ' testmsg '\n'];
        fprintf(msg);
        return;
    else
        msg = cell(1, scope_level + 3);
        msg{1} = 'Warning:\n';
        msg{end} = '\n';
    end


    for k = 1:scope_level
        indent = repmat(' ', 1, k + 1);
        fname = st(k).name;
        fline = st(k).line;
        msg{k + 1} = [indent, 'In ' fname, ' at line (', num2str(fline), ')\n'];
    end

    indent = repmat(' ', 1, k + 4);

    if error_in_args
        msg{k + 2} = [indent emsg.message];
    else
        msg{k + 2} = [indent testmsg];
    end

    fprintf(cell2str(msg, ''));
end
