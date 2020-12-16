function [result, failed_items] = cellfun(func, icell)
% function [result, failed_items] = cellfun(func,icell)
%
% A MATLAB cellfun function that wraps errors
% in empty results.
% The items that triggered the fails may be returned.
%
% Inputs:
%
% func [function_handle] - a FH to apply to each cell member
% icell [cell[Any]] - a cell where func will be applied itemwise.
%
% Outputs:
%
% result [cell{any}] - the result of func(icell{k})
% failed_items [cell{any}] - the icell{k} items that erroed.
%
% Example:
%
% %valid inputs
% [result] = IMOS.cellfun(@iscell,{{},{}});
% assert(all(cell2mat(result)));
%
% %empty results for invalid evaluations
% [result,failed_items] = IMOS.cellfun(@zeros,{'a',1,'b'});
% assert(isempty(result{1}))
% assert(isequal(result{2},0))
% assert(isempty(result{3}))
% assert(isequal(failed_items{1},'a'))
% assert(isequal(failed_items{2},'b'))
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2)

if ~isfunctionhandle(func)
    errormsg('First argument `func` is not a function handle')
elseif ~iscell(icell)
    errormsg('Second argument `icell` is not a cell')
end

nc = numel(icell);
result = cell(1, nc);
failed_items = {};
fcount = 0;

try
    [result] = cellfun(func, icell, 'UniformOutput', false);
catch

    for k = 1:numel(icell)

        try
            result{k} = func(icell{k});
        catch

            if nargout > 1

                if fcount == 0
                    failed_items = cell(1, nc - k);
                end

                fcount = fcount + 1;
                failed_items{fcount} = icell{k};
            end

        end

    end

end

if nargout > 1 && fcount > 0
    failed_items = failed_items(1:fcount);
end

end
