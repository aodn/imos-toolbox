function [spikes] = imosSpikeClassifierNonBurstSavGolOTSU(signal, window, pdeg, nbins, oscale)
% function spikes = imosSpikeClassifierNonBurstSavGolOTSU(signal, window, pdeg, nbins, oscale)
%
% Detect spikes in signal by using the Otsu threshold method
% applied to the noise estimated by a Savitzy Golay Filter applied on the signal.
%
% The routine uses the SavGol.m implementation provided by
% Ken Ridgway.
%
% Inputs:
%
% signal - the signal.
%  window - the SavGol window argument (odd integer).
%  pdeg - the SavGol lsq polynomial order (integer).
%  nbins - the number of histogram bins in the OTSU threshold method (positive integer)
%  oscale - a constant scale factor to weight the OTSU threshold method (positive number)
%
% Outputs:
%
% spikes - spikes indexes.
%
% Example:
%
% t = 0:3600:86400*5;
% omega = 2*pi/86400;
% signal = 10*sin(omega*t);
% signal([20]) = max(signal).^3;
% [spikes] = imosSpikeClassifierNonBurstSavGolOTSU(signal,5,2,100,5);
% assert(spikes,20)
%
% author: Unknown
% author: Ken Ridgway
% author: hugo.oliveira@utas.edu.au [rewrite/refactoring]

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
    window = 5; %minimum filtering
    pdeg = 2; %quadratic polynomial
    nbins = 256; % default otsu bins
    oscale = 1; %arbitrary scale used to reduce the otsu threshold
elseif nargin == 2
    pdeg = 2; %quadratic polynomial
    nbins = 256; % default bins in despiking1
    oscale = 1; %arbitrary scale used to reduce the otsu threshold
elseif nargin == 3
    nbins = 256; % default bins in despiking1
    oscale = 1; %arbitrary scale used to reduce the otsu threshold
elseif nargin == 4
    oscale = 1; %arbitrary scale used to reduce the otsu threshold
end

if window <= 3
    error('Window need to be even and larger than 3')
else

    if rem(window, 2) == 0
        window = window - 1;
    end

end

fsignal = SavGol(signal, (window - 1) / 2, (window - 1) / 2, pdeg);
noise = signal - fsignal;
abs_noise = abs(noise);
otsu = otsu_threshold(abs_noise, nbins);
threshold = otsu / oscale;
ring_spikes = find(abs_noise > threshold | abs_noise <- threshold);
spikes = centred_indexes(ring_spikes);

end

function [cgind] = centred_indexes(sind)
% Return the central value of a group of
% consecutive integers in a sorted array of integers.

s_start = sind(1);
s_end = sind(end);
cgind = sind*NaN;
c=1;
for k = 1:length(sind) - 1
    adjacent = sind(k + 1) - sind(k) <= 1;
    if adjacent
        continue
    end

    s_end = sind(k);
    cgind(c) = floor((s_end + s_start) / 2);
    s_start = sind(k + 1);
    c = c+1;
end
cgind(end) = floor((s_end + s_start) / 2);

cgind = cgind(~isnan(cgind));
end
