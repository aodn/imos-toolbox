function Yi = LeanInterp(X, Y, Xi)
% Code to perform linear interpolation without using the interp1 routine in
% matlab. Reduces the time taken to perform the operation by approximately
% 0.5.
% Original code from Matlab help forum. Adapted to suit the ADCP data
% Bec Cowley, May 2020

% % Linear interpolation algorithm - roughly
% % yi = y + (xi -x).*(diff(y)/diff(x))
% for a = 1:length(Y)-1
%     y(a) = Y(a)+(Xi(a)-X(a))*(Y(a+1)-Y(a))/(X(a+1)-X(a));
% end

X  = X(:);
Xi = Xi(:);
Y  = Y(:);
nY = numel(Y);

[n,edges, Bin] = histcounts( X,[0;Xi;Xi(end)+Xi(2)-Xi(1)+1]);  
H            = diff(X);
d     = find((Bin >= nY));

if ~isempty(d)>0
   Bin(d(1):end) = nY - 1;
end

Ti = Bin + (Xi - X(Bin)) ./ H(Bin);

% Interpolation parameters:
Si = Ti - floor(Ti);
Ti = floor(Ti);

% Shift frames on boundary:
d     = find((Ti >= nY));
if ~isempty(d)
    Ti(d(1):end) = nY - 1;
    Si(d(1):end) = 1;
end
d0     = find((Ti == 0));
if ~isempty(d0)
    Ti(d0) = 1;
    Si(d0) = 1;
end

% Now interpolate:
Yi = Y(Ti) .* (1 - Si) + Y(Ti + 1) .* Si;

%tidy up
Yi(d) = NaN;
Yi(d0) = NaN;


