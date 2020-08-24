function [spikes, fsignal] = imosSpikeClassifierHampel(signal, half_window_width, madfactor, lower_mad_limit)
% function spikes, fsignal = imosSpikeClassifierHampel(signal, half_window_width, madfactor, lower_mad_limit)
%
% A wrapper to Hampel classifier.The hampel method is a robust parametric denoising filter that uses
% the MAD deviation (scaled) from the median in a pre-defined centred window.
%
% See also hampel.m.
%
% Inputs:
%
% signal - A 1-d signal.
% half_window_width - A half_window_width index range (the full window size will be 1+2*half_window_width)
% madfactor - A multiplying scale for the standard deviation.
% lower_mad_limit - a lower threshold for the MAD values, which values below will be ignored.
%
% Outputs:
%
% spikes - An array with spikes indexes.
% fsignal - A filtered signal where the spikes are substituted by median values of the window.
%
% Example:
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
narginchk(1, 4)

if nargin == 1
    half_window_width = 3;
    madfactor = 10;
    lower_mad_limit = 0.0;
elseif nargin == 2
    madfactor = 10;
    lower_mad_limit = 0.0;
elseif nargin == 3
    lower_mad_limit = 0.0;
end

[fsignal, bind, ~, smad] = hampel(signal, half_window_width, madfactor);
above_limit = smad > lower_mad_limit;
spikes = find(bind .* above_limit);
end
