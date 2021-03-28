function [bool, eqarr, pequal] = isequal_tol(a, b, decrange)
% function [bool,eqarr, pequal] = isequal_tol(a,b, decrange)
%
% Compare floating numbers up to a decimal range,
% via quantisation.
%
% Inputs:
%
% a [array] - a singleton or array of numbers.
% b [array] - as above.
% decrange [int] - the range in decimals.
%               Default: 12 decimal cases.
%
% Outputs:
%
% bool[logical] - equality result.
% eqarr[integer] - the equality array.
% pequal[double] - the percent of data that is equal
%                  at the decimal range selected.
%
% Example:
%
% assert(isequal_tol(0,0,1))
% assert(isequal_tol(1,1,1))
% assert(isequal_tol(1,1,1))
% assert(isequal_tol(1,1,12))
% assert(isequal_tol(1.0013,1.0012,3))
% assert(~isequal_tol(1.0013,1.0012,4))
% assert(isequal_tol(1e-13,1e-13+1e-15,14))
% assert(~isequal_tol(-1e-13,-1e-13+1e-15,15))
% try;isequal_tol(1e30+0.01,1e30,1);assert(false); catch; assert(true);end
% assert(isequal_tol([1],[1,1,1,1.001],2))
% assert(~isequal_tol([1],[1,1,1,1,1.001],3))
% assert(isequal_tol([1,2,3;3,2,1],[1.01,2.02,3.03;3.01,2.02,1.03],1))
% [x,y,p] = isequal_tol([1,2,3,4,5;5,4,3,2,1],[0.9,1.8,2.7,3.6,4.5;5.1,4.2,3.3,2.4,1.5],1);
% assert(~x)
% assert(~all(y,'all'))
% assert(y(end)==0)
% assert(all(y(1:end-1)==1,'all'))
% assert(p>=.9)
%
% author: hugo.oliveira@utas.edu.au
%
bool = false;
eqarr = [];

narginchk(2, 3)

if nargin < 3
    cfun = str2func(class(a));
    qrange = cfun(1e-12);
else
    if decrange < 1
        errormsg('Decimal range argument must be positive and non-zero.')
    end
    cfun = str2func(class(a));
    qrange = cfun(10.^(-abs(decrange)));
end

alen = numel(a);
blen = numel(b);

a_is_singleton = alen == 1;
b_is_singleton = blen == 1;

diff_size = alen ~= blen;
both_non_singleton = ~a_is_singleton && ~b_is_singleton;
invalid_input = diff_size && both_non_singleton;

if invalid_input
    errormsg('Argument size/shape mismatch.')
end

simple_float_comparison = a_is_singleton && b_is_singleton;

if simple_float_comparison
    bool = compare(a, b, qrange);
    eqarr = bool;
    pequal = double(bool*length(eqarr));
    return
end

if a_is_singleton
    loopindex = blen;
    func = @(k)(compare(a, b(k), qrange));

    if nargout > 1
        eqarr = zeros(size(b), 'logical');
    end

elseif b_is_singleton
    loopindex = alen;
    func = @(k)(compare(a(k), b, qrange));

    if nargout > 1
        eqarr = zeros(size(a), 'logical');
    end

else
    loopindex = alen;
    func = @(k)(compare(a(k), b(k), qrange));

    if nargout > 1
        eqarr = zeros(size(a), 'logical');
    end

end

for k = 1:loopindex
    bool = func(k);

    if nargout > 1 && bool
        eqarr(k) = 1;
    elseif nargout < 1 && ~bool
        return
    end

end

if nargout > 1
    bool = all(eqarr, 'all');
end

if nargout > 2
    pequal = sum(eqarr,'all')/loopindex;
end

end

function bool = compare(a, b, qrange)
    if qrange>=1e-1
        bool = isequaln(int64(a),int64(b));
    else
        bool = isequaln(uniformQuantise(a, qrange), uniformQuantise(b, qrange));
    end
end
