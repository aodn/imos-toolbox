function [spikes,threshold] = imosSpikeClassifierOTSU(signal, nbins, oscale, centralize)
% function [spikes,threshold] = imosSpikeClassifierOTSU(signal, nbins, oscale, centralize)
%
% Detect spikes in by using the Otsu threshold method.
%
% Inputs:
%
%  signal - the signal.
%  nbins - the number of histogram bins in the OTSU threshold method (positive integer)
%  oscale - a constant scale factor to weight the OTSU threshold method (positive number)
%  centralize - a boolean to average/centralize the detected indexes (default: true)
%
% Outputs:
%
% spikes - spikes indexes.
% threshold - the threshold used for spike detection.
%
% Example:
%
% signal = [0,1,0];
% [spikes] = imosSpikeClassifierOTSU(signal,3,1,false);
% assert(spikes==2)
%
% %centralized
% signal = [0,1,1,1,0]
% [spikes] = imosSpikeClassifierOTSU(signal,3,1,false);
% assert(spikes==[4,5,6])
% [spikes] = imosSpikeClassifierOTSU(signal,3,1,true);
% assert(spikes==[5])
%
% %harmonic
% omega = 2*pi/86400;
% t = 0:3600:86400*5;
% signal = 10*sin(omega*t)
% signal([10,20]) = max(signal)^3;
% [spikes] = imosSpikeClassifierOTSU(signal,100,1,true);
% assert(spikes==[10,20])
%
% %
% omega = 2*pi/86400;
% t = 0:3600:86400*5;
% signal = 10*sin(omega*t)
% signal(20) = signal(20)*2;
% signal(21:end) = signal(21:end)+signal(20);
% signal([33,55]) = sign(signal([33,55])).*signal([33,55]).^2;
% [spikes] = imosSpikeClassifierOTSU(signal,100,1,true);
% assert(spikes==[33,55])
%
%
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
    nbins = 256;
    oscale = 1;
    centralize = true;
elseif nargin == 2
    oscale = 1;
    centralize = true;
elseif nargin == 3
    centralize = true;
end

otsu = otsu_threshold(signal, nbins);
threshold = otsu / oscale;
spikes = find(signal > abs(threshold) | signal < -1*abs(threshold));
if centralize
    spikes = centred_indexes(spikes);
end

end

function [cgind] = centred_indexes(sind)
% Return the central value of a group of
% consecutive integers in a sorted array of integers.

s_start = sind(1);
cgind = sind * NaN;
c = 1;

for k = 1:length(sind) - 1
    adjacent = sind(k + 1) - sind(k) <= 1;

    if adjacent
        continue
    end

    s_end = sind(k);
    cgind(c) = floor((s_end + s_start) / 2);
    s_start = sind(k + 1);
    c = c + 1;
end

s_end = sind(end);
cgind(end) = floor((s_end + s_start) / 2);
cgind = cgind(~isnan(cgind));
end
