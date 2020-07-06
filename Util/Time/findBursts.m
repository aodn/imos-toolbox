function [burst_index_ranges, number_of_samples_in_burst, burst_sampling_interval, burst_duration, burst_interval] = findBursts(time, prec)
%function [burst_index_ranges, number_of_samples_in_burst, burst_sampling_interval, burst_duration, burst_interval] = findBursts(time, prec)
%
% Find bursts in a datenum time array iteratively. This
% function provide an improved burst detection for the
% edges of the series and when the haphazard bursts occurs.
%
% Inputs:
%
% time - the datenum array.
% prec - the time precision string.
%        Default: 'microsecond'
%
% Outputs:
%
% burst_index_ranges - [cell of 1x2 arrays] a cell with individual burst index ranges [start,end]
% number_of_samples_in_burst - [array] with the number of samples in each burst.
% burst_sampling_interval - [array] the burst sampling interval of every burst
% burst_duration - [array] the burst duration of every burst.
% burst_interval - [array] the burst time interval between every burst.
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
if nargin < 2
    prec = 'microsecond';
end

min_diff_precision = stepsInDay(nextLowerTimePrecision(prec)) / (stepsInDay(prec).^1.5);

n = numel(time);

%preallocate at a 1/5 of the size
burst_index_ranges = cell(1, floor(n / 5));
number_of_samples_in_burst = zeros(1, floor(n / 5));
burst_sampling_interval = zeros(1, floor(n / 5));
burst_duration = zeros(1, floor(n / 5));
burst_interval = [];
sample_steps_in_burst = zeros(1, floor(n / 5));

if isempty(time)
    return
end

ts = time(1);
tsp1 = time(2);
pdt1 = timeQuantisation(tsp1 - ts, prec);

%detect first time of series is the end of a prev burst
if length(time) > 5
    tmode = timeQuantisation(mode(diff(time(1:5))), prec);
    first_data_is_single_burst = pdt1>tmode;
else
    first_data_is_single_burst = false;
end

%init accordingly
if first_data_is_single_burst
    cind = 1;
    tmp = [2, NaN]; %TODO refact this
    burst_index_ranges{cind} = [1, 1];
    number_of_samples_in_burst(cind) = 1;
    burst_sampling_interval(cind) = 0;
    burst_duration(cind) = 0;
    start = 3;
    pdt = timeQuantisation(time(3) - time(2), prec);
else
    cind = 0;
    tmp = [1, NaN];
    start = 2;
    pdt = pdt1;
end

sample_steps_in_burst(1) = pdt1;
samples = 1;

for k = start:n - 1%TODO: refact this
    cdt = timeQuantisation(time(k) - time(k - 1), prec);
    dtdiff = abs(cdt - pdt) < min_diff_precision;

    within_burst = dtdiff || cdt == 1;

    if within_burst
        tmp(2) = k;
        samples = samples + 1;
        sample_steps_in_burst(samples) = cdt;
    else

        if isnan(tmp(2))% singleton burst in the middle
            tmp(2) = k;
            samples = samples + 1;
        end

        cind = cind + 1;
        burst_index_ranges{cind} = tmp;
        number_of_samples_in_burst(cind) = samples;
        burst_sampling_interval(cind) = mode(sample_steps_in_burst(1:samples));
        burst_duration(cind) = timeQuantisation(time(tmp(2)) - time(tmp(1)), prec);

        tmp(1) = k;
        tmp(2) = NaN;
        samples = 1;
        pdt = timeQuantisation(time(k + 1) - time(k), prec);
        sample_steps_in_burst(2:samples) = 0;
        sample_steps_in_burst(1) = pdt;
    end

end

%handle boundary conditions
single_burst_at_right = isnan(tmp(end));
last_burst_at_end = tmp(end) + 1 == n;

if single_burst_at_right
    tmp(end) = n;
    samples = samples + 1;
elseif last_burst_at_end

    if cind > 0
        dt_at_end = time(tmp(end) + 1) - time(tmp(end));
        is_last_point_single_burst = timeQuantisation(dt_at_end, prec) ~= burst_sampling_interval(cind);

        if ~is_last_point_single_burst
            tmp(end) = tmp(end) + 1;
            samples = samples + 1;
        end

    else
        tmp(end) = tmp(end) + 1;
        samples = samples + 1;
    end

end

%store last valid burst
cind = cind + 1;
burst_index_ranges{cind} = tmp;
number_of_samples_in_burst(cind) = samples;
burst_sampling_interval(cind) = pdt;
burst_duration(cind) = timeQuantisation(time(tmp(2)) - time(tmp(1)), prec);

%handle incomplete endings with singleton bursts
fix_end_burst = timeQuantisation(time(end) - time(end - 1), prec) > burst_duration(cind);

if fix_end_burst
    cind = cind + 1;
    burst_index_ranges{cind} = [n n];
    number_of_samples_in_burst(cind) = 1;
    burst_sampling_interval(cind) = 0;
    burst_duration(cind) = 0;
else

    if burst_index_ranges{cind}(end) ~= n
        burst_index_ranges{cind}(end) = n;
        tmp = burst_index_ranges{cind};
        number_of_samples_in_burst(cind) = number_of_samples_in_burst(cind) + 1;
        burst_duration(cind) = timeQuantisation(time(tmp(2)) - time(tmp(1)), prec);
    end

end

%reduce and estimate burst_interval
burst_index_ranges = burst_index_ranges(1:cind);
number_of_samples_in_burst = number_of_samples_in_burst(1:cind);
burst_sampling_interval = burst_sampling_interval(1:cind);
burst_duration = burst_duration(1:cind);

burst_interval = zeros(1, cind - 1);

for k = 2:cind
    interval = time(burst_index_ranges{k}(end)) - time(burst_index_ranges{k - 1}(1)) - burst_duration(k - 1);
    burst_interval(k - 1) = timeQuantisation(interval, prec);
end

end
