function [spikes] = imosSpikeClassifierRunningStats(signal, scalefun, dispersionfun, dispersion_factor)
% function [spikes] = imosSpikeClassifierRunningStats(signal, scalefun, dispersionfun, dispersion_factor)
%
% A simple thresholding method based on user defined deviations around a central scale. Values above
% the dispersion will be tagged.
%
% Inputs:
%
% signal - A 1-d signal.
% scalefun - the function to estimate the centre of the distribution. (e.g. mean or median)
%          Default: @mean
% dispersionfun - the function to estimate the dispersion (e.g. std, mean_absolute_deviation, median_absolute_deviation)
%               Default: @std
% dispersion_factor - the multiplying factor for the dispersion.
%                   Default: 2
%
% Outputs:
%
% spikes - An array with spikes indexes.
% cscale - the computed scale
% cdispersion - the computed dispersion (scaled).
%
% Example:
% z = randn(1,10);
% z(10) = 10000;
% [spikes] = imosSpikeClassifierRunningStats(z,@mean,@std,2);
% assert(spikes(10)==1)
% assert(spikes(1:9)==0)
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
narginchk(1,4)
if nargin==1
	scalefun = @nanmean;
	dispersionfun = @nanstd;
	dispersion_factor = 2;
elseif nargin == 2
	dispersionfun = @nanstd;
	dispersion_factor = 2;
elseif nargin == 3
	dispersion_factor = 2;
end

cscale = scalefun(signal);
cdispersion = dispersion_factor * dispersionfun(signal);
above_and_below = (signal > (cscale + cdispersion)) + (signal < (cscale - cdispersion));
spikes = find(above_and_below);
end
