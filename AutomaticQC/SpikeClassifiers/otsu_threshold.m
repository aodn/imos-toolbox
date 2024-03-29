function [threshold] = otsu_threshold(signal, nbins)
% function threshold = otsu_threshold(signal,nbins)
%
% Compute the Otsu threshold of a one dimensional signal.
%
% The Otsu threshold is a binary quantization threshold
% that minimize (maximize) the within (between) class variance.
%
% Inputs:
%
% signal - the input signal.
% nbins - the number of bins/partitions in the histogram
%         Default: 256.
%
% Outputs:
%
% threshold - The optimized threshold
%
% Example:
%
% % find different samplings
% dsignal = diff([0:10:100, 101:110]);
% [t] = otsu_threshold(dsignal,2);
% assert(t>1);
% assert(isequal(find(dsignal>t),1:10))
% [t] = otsu_threshold(dsignal,100);
% assert(t>1);
%
% % spike simple case
% x = randn(1,100)*10;
% spikes = [3,30:40,90];
% x(spikes) = 100;
% dsignal = diff(x);
% t = otsu_threshold(dsignal,2);
% assert(t<100);
% assert(abs(x(3)-x(2))>t)
% assert(abs(x(30)-x(29))>t)
% assert(abs(x(90)-x(89))>t)
% 
% % simple threshold only detects the first
% % occurence, and with a shifted index given
% % the difference operation
% assert(isequal(find(dsignal>t),[2,29,89]))
%
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
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

if nargin == 1
    nbins = 256; %based on original - grayscale levels in images
end

nsample = length(signal);
[c, amplitude] = hist(signal, nbins);
norm_counts = c ./ nsample;

prev_variance = 0;
threshold = 0;

for i = 1:nbins - 1

    if norm_counts(i) == 0
        continue
    end

    %left class
    a1range = 1:i;
    A1 = sum(norm_counts(a1range)); % A1 = P(left_class)
    A1m = sum(amplitude(a1range) .* norm_counts(a1range)) / A1;

    %right class
    a2range = (i + 1):nbins;
    A2 = 1 - A1; % optmized since range is [0,1]
    A2m = sum(amplitude(a2range) .* norm_counts(a2range)) / A2;

    variance = A1 * A2 * (A1m - A2m)^2; %variance between class

    if variance > prev_variance
        threshold = amplitude(i + 1); % t = the next histogram bin limit
        prev_variance = variance;
    end

end
