function g = SavGol (f, nl, nr, M)

% SAVGOL SavGol smoothes the data in the vector f by means of a
%        Savitzky-Golay smoothing filter.
%
%        Input: f : noisy data
%        nl: number of points to the left of the reference point
%        nr: number of points to the right of the reference point
%        M : degree of the least squares polynomial
%
%        Output: g: smoothed data
%
%        W. H. Press and S. A. Teukolsky,
%        Savitzky-Golay Smoothing Filters,
%        Computers in Physics, 4 (1990), pp. 669-672.

% matrix A
A = ones (nl+nr+1, M+1);
for j = M:-1:1,
  A (:, j) = [-nl:nr]' .* A (:, j+1);
end

% filter coefficients c
[Q, R] = qr (A);
c = Q (:, M+1) / R (M+1, M+1);

% smoothing of the noisy data
% Note that there are two equivalent ways to apply the Savitzky-Golay
% filter to the vector f.  In the first case we use a for-loop whereas
% in the second case we use the faster built-in function filter.
%
% g = f;
% n = size (f);
% for i = 1+nl:n-nr,
%   g (i) = c' * f (i-nl:i+nr);
% end
%
n = length (f);
g = filter (c (nl+nr+1:-1:1), 1, f);
g (1:nl) = f (1:nl);
g (nl+1:n-nr) = g (nl+nr+1:n);
g (n-nr+1:n) = f (n-nr+1:n);
