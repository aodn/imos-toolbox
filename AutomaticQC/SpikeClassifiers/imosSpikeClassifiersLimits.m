function [limits] = imosSpikeClassifiersLimits(len)
% function [limits] = imosSpikeClassifiersLimits(len)
%
% Load the types and limits of all imosTimeSeriesSpikeQC classifiers
%
% Inputs:
%
% len - the length of the time series (integer)
%
% Outputs:
%
% limits - A structure with the limits.
%
% Example:
%
% len = 100
% [limits] = imosTimeSeriesSpikeQCLimits(len)
% assert(limits.hampel_half_window_width.min==1)
% assert(limits.hampel_half_window_width.max==len/2)
% assert(limits.hampel_madfactor.max = 20)
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

limits = struct();
limits.hampel_half_window_width.min = int64(1);
limits.hampel_half_window_width.max = int64(len / 2);
limits.hampel_half_window_width.help = '[Int] such as <half_window_width,1,half_window_width>. Increase this value to include more data in the window';

limits.hampel_madfactor.min = .5;
limits.hampel_madfactor.max = 20;
limits.hampel_madfactor.help = '[float] A scale multipler for the MAD <N*mad>. Increase this value to reduce sensitivity';

limits.hampel_lower_mad_limit.min = 0.;
limits.hampel_lower_mad_limit.max = 0.5;
limits.hampel_lower_mad_limit.help = '[float] Clip MAD values to above this limit. Increase slightly to reduce sensitivity for low/constant regions';

limits.otsu_savgol_window.min = int64(3);
limits.otsu_savgol_window.max = int64(len / 3);
limits.otsu_savgol_window.help = '[int] The full window width for the SavGol low-pass filter. Increase the window to increase the number of noise considered. Too large values affect resolution at the signal boundaries';

limits.otsu_savgol_pdeg.min = int64(1);
limits.otsu_savgol_pdeg.max = int64(4);
limits.otsu_savgol_pdeg.help = '[int] The least squares polynomial order. A larger value may increase noise level but move spike locations.';

limits.otsu_savgol_nbins.min = int64(2);
limits.otsu_savgol_nbins.max = int64(256);
limits.otsu_savgol_nbins.help = '[int] The number of histogram bins when tracing the noise level. A larger value increase spike magnitude resolution at the window level.';

limits.otsu_savgol_oscale.min = 0.01;
limits.otsu_savgol_oscale.max = 10;
limits.otsu_savgol_oscale.help = '[float] A scale factor to multiply the noise threshold computed on the noise level. A large value increase the threshold (reduce detection).';

limits.otsu_threshold_nbins.min = int64(2);
limits.otsu_threshold_nbins.max = int64(256);
limits.otsu_threshold_nbins.help = '[int] The number of histogram bins when tracing the noise level. A larger value reduce global spike magnitude resolution.';

limits.otsu_threshold_oscale.min = 1e-5;
limits.otsu_threshold_oscale.max = 10;
limits.otsu_threshold_oscale.help = '[float] A scale factor to multiply the noise threshold computed on the noise level. A large value increase the threshold (reduce detection).';

limits.otsu_threshold_centralise.min = false;
limits.otsu_threshold_centralise.max = true;
limits.otsu_threshold_centralise.help = '[boolean] Force centralization. Required to be 1.';

limits.burst_hampel_use_burst_window.min = false;
limits.burst_hampel_use_burst_window.max = true;
limits.burst_hampel_use_burst_window.help = '[boolean] Consider the hampel_half_window_width at the burst level instead of sample level. Set to true (false) to use more than one (only one) burst in a hampel window.';

limits.burst_hampel_half_window_width.min = int64(0);
limits.burst_hampel_half_window_width.max = int64(len);
limits.burst_hampel_half_window_width.help = '[Int] such as <half_window_width,1,half_window_width>. Increase this value to include more data in the window or more bursts in the window (see burst_hampel_use_burst_window).';

limits.burst_hampel_madfactor.min = .5;
limits.burst_hampel_madfactor.max = 20;
limits.burst_hampel_madfactor.help = '[float] A scale multipler for the MAD <N*mad>. Increase this value to reduce sensitivity.';

limits.burst_hampel_lower_mad_limit.min = 0;
limits.burst_hampel_lower_mad_limit.max = 0.5;
limits.burst_hampel_lower_mad_limit.help = '[float] Clip MAD values to above this limit. Increase slightly to reduce sensitivity for low/constant regions';

limits.burst_hampel_repeated_only.min = false;
limits.burst_hampel_repeated_only.max = true;
limits.burst_hampel_repeated_only.help = '[boolean] Only consider repeated spikes. Ignored if use_burst_window == 0. May reduce sensitivity of large jumps in burst-to-burst variability.';

mean_absolute_deviation = @(x)mad(x, 0);
mad_mean = @(x)(mean_absolute_deviation(x)); % display when inspecting

median_absolute_deviation = @(x)(mad(x, 1));
mad_median = @(x)(median_absolute_deviation(x)); %display when inspecting

limits.burst_runningstats_scalefun.available = {@nanmean, @nanmedian};
limits.burst_runningstats_scalefun.help = '[function_handle] The function to estimate the scale/central value.';

limits.burst_runningstats_dispersionfun.available = {@nanstd, mad_median, mad_mean};
limits.burst_runningstats_dispersionfun.help = '[function_handle] The function to estimate the dispersion/deviations from scale.';

limits.burst_runningstats_dispersion_factor.min = 1;
limits.burst_runningstats_dispersion_factor.max = 20;
limits.burst_runningstats_dispersion_factor.help = '[float] A scale factor to multiply the dispersion. A large value decrease sensitivity.';

end
