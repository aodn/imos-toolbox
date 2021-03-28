function [filtered, unmatched] = filterFields(astruct, astr)
% function [filtered,unmatched] = filterFields(astruct,astr)
%
% Returns only fieldnames that partially or completely
% match a string.
%
% Inputs:
%
% astruct [struct] - a structure with fields
% astr [str] - a string to match against the fieldnames
%
% Outputs:
%
% filtered [cell{str}] - matched fieldnames
% unmatched [cell{str}] - the unmatched fieldnames.
%
% Example:
%
% %basic usage
% x = struct('a','','aa','','b','','bb','','ab','','ba','');
% [filtered,unmatched] = filterFields(x,'a');
% assert(numel(filtered)==4)
% assert(numel(unmatched)==2)
% assert(strcmp(unmatched{1},'b'))
% assert(strcmp(unmatched{2},'bb'))
%
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(2, 2)

fnames = fieldnames(astruct);
where = contains(fnames, astr);
filtered = fnames(where);

if nargout > 1
    unmatched = fnames(~where);
end

end
