function [spikes, fsignal] = imosSpikeClassifierHampel(signal, window, stdfactor)
% function spikes, fsignal = imosSpikeClassifierHampel(signal, window, stdfactor)
%
% A wrapper to Hampel, a median windowed filter, for both
% Burst and Equally spaced time series.
%
% The hampel method is a robust parametric denoising filter that uses
% the MAD deviation (scaled) from the median in a pre-defined
% indexed centred window.
%
% See also hampel.m.
%
% Inputs:
%
% signal - A 1-d signal.
% window - A window index range. If signal is in burst mode, this is ignored.
% stdfactor - A multiplying scale for the standard deviation.
%
% Outputs:
%
% spikes - An array with spikes indexes.
% fsignal - A filtered signal where the spikes are subsituted
%           by the median of the window.
%
% Example:
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

if nargin < 3
    window = 3;
    stdfactor = 10;
elseif nargin < 2
    stdfactor = 10;
end

[fsignal, bind, ~, ~] = hampel(signal, window, stdfactor);
spikes = find(bind);
end
