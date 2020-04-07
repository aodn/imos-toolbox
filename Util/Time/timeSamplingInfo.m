function [info] = timeSamplingInfo(time, prec)
    % function [info] = timeSamplingInfo(time, prec)
    %
    % Report information about a datenum time array
    % given a time precision, including burst Information, if any.
    %
    % See Examples below to quantise time and to
    % allow (ignore) round ups (timescales).
    %
    % Inputs:
    %
    % time - a datenum time array
    % prec - a time precision string for time interval matching.
    %        Default to 'microsecond', i.e.
    %        half-microsecond or lower sampling is quantised/floored.
    %
    % Outputs:
    %
    % info - a structure with information regarding time sampling.
    %
    %     % sampling information
    %     .assumed_time_precision - the precision
    %     .constant_vector - if time is constant
    %     .number_of_sampling_steps - the number of different samplings at given precision
    %     .sampling_steps - the sampling periods in days
    %     .sampling_steps_in_seconds - ditto but in seconds
    %     .sampling_steps_median - the most frequent value of sampling dt.
    %     .sampling_steps_median_in_seconds - ditto but in seconds
    %     .sampling_step_mode - the most ocurring value of the sampling dt
    %     .sampling_step_mode_in_seconds - ditto but in seconds
    %     .consistent_sampling - if median == mode.
    %     .repeated_samples - if the time variable got repeated values
    %     .unique_sampling - if sampling intervals are unique
    %     .uniform_sampling - if sampling intervals are uniform
    %     .monotonic_sampling - if sampling are monotonic [incr/decr]
    %     .progressive_sampling - values are generally increasing
    %     .regressive_sampling - values are generally decreasing
    %     .non_uniform_sampling_indexes - left-most indexes of non-uniform sampling.
    %     .jump_magnitude - the time distance between the non-uniform  and the next uniform or non-uniform sampling
    %     .jump_forward_indexes - non_uniform boolean array where positive non-uniform sampling is found
    %     .jump_backward_indexes - as above, but for negative shifts.
    %
    %    %  The burst sampling info.
    %     .is_burst_sampling - true if burst were detected
    %     .is_burst_sampling_exact - true if bursts are exact at `.burst_sampling_units`.
    %     .is_burst_sampling_repeats - true if repeated sampling at burst level, such as repeated timestamps.
    %     .burst_sampling_units = the precision for burst sampling - may be different from `prec`.
    %     .burst_sampling_interval - the burst sampling interval.
    %     .burst_sampling_interval_in_seconds - as above, but in seconds.
    %     .burst_duration - the burst duration.
    %     .burst_duration_in_seconds - as above, but in seconds.
    %
    % Example:
    % % basic - ignore small drifts at requested scale
    %
    % info = timeSamplingInfo([1,2,3,4,5.3],'day');
    % assert(info.uniform_sampling);
    % assert(all([info.unique_sampling,info.monotonic_sampling,info.progressive_sampling]));
    %
    % % extra reports about sampling
    %
    % info = timeSamplingInfo([1,2,1,3,1,4,1,5,1],'day');
    % assert(~all([info.unique_sampling,info.progressive_sampling,info.regressive_sampling,info.monotonic_sampling]));
    % assert(isequal(info.sampling_steps_mode,[]));
    % assert(all(info.jump_forward_indexes==[1 0 1 0 1 0 1 0]));
    % assert(all(info.jump_backward_indexes==[0 1 0 1 0 1 0 1]));
    %
    % % ignore a different scale - microsecond.
    %
    % info = timeSamplingInfo([1,2,3,4+0.49/86400,5],'second');
    % assert(info.repeated_samples==0);
    % assert(info.sampling_steps==1);
    %
    % % trigger different sampling since diff is at or above half the requested scale.
    %
    % info = timeSamplingInfo([1,2,3,4+0.5/86400,5],'second');
    % assert(info.repeated_samples==0);
    % assert(isequal(info.sampling_steps*86400,[86400,86401]));
    %
    % % ignore constant offsets in clock drifting
    %
    % drifts = [0,0,0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1]/86400;
    % times = [1,2,3,4,5,6,7,8,9,10,11,12,13];
    % info = timeSamplingInfo(times+drifts,'second');
    % assert(info.sampling_steps_in_seconds==86400);
    %
    % % report different samplings since drifts are at or above half the requested scale.
    %
    % drifts = [0,0.5,0.5,0.5,0.75,1,1.25,1.5,3,6,9,12,24]/86400;
    % times = [1,2,3,4,5,6,7,8,9,10,11,12,13];
    % info = timeSamplingInfo(times+drifts,'second');
    % assert(isequal(info.sampling_steps_in_seconds,86400+[0,1,2,3,12]));
    %
    %
    % author: hugo.oliveira@utas.edu.au
    %

    % Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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

    info = struct();
    info.assumed_time_precision = prec;
    info.number_of_sampling_steps = 0;
    info.sampling_steps = [];
    info.sampling_steps_in_seconds = [];
    info.sampling_steps_median = [];
    info.sampling_steps_median_in_seconds = [];
    info.sampling_steps_mode = [];
    info.sampling_steps_mode_in_seconds = [];
    info.consistent_sampling = [];
    info.constant_vector = [];
    info.repeated_samples = [];
    info.unique_sampling = [];
    info.uniform_sampling = [];
    info.monotonic_sampling = [];
    info.progressive_sampling = [];
    info.regressive_sampling = [];
    info.non_uniform_sampling_indexes = [];
    info.jump_magnitude = [];
    info.jump_forward_indexes = [];
    info.jump_backward_indexes = [];

    if isempty(time) || length(time) == 1
        return
    end

    info.unique_sampling = isunique(time);

    tdiff = timeQuantisation(diff(time),prec);

    info.sampling_steps = unique(tdiff);
    info.number_of_sampling_steps = length(info.sampling_steps);
    info.sampling_steps_in_seconds = unique(timeQuantisation(tdiff*86400,'second'));
    info.constant_vector = all(info.sampling_steps == 0);
    info.repeated_samples = info.sampling_steps(1) == 0;
    info.uniform_sampling = info.number_of_sampling_steps == 1;

    mfdt = median(tdiff);
    modt = mode(tdiff);
    tdiff_sign = sign(tdiff);

    info.consistent_sampling = modt == mfdt;
    info.sampling_steps_median = mfdt;
    info.sampling_steps_median_in_seconds = mfdt*86400;
    info.sampling_steps_mode = modt;
    info.sampling_steps_mode_in_seconds = modt*86400;
    info.monotonic_sampling = ~all(tdiff_sign==0) && ~any(diff(tdiff_sign));

    mfdt_sign = mode(tdiff_sign); % use median to avoid symmetric false positives
    info.progressive_sampling = mfdt_sign > 0;
    info.regressive_sampling = mfdt_sign < 0;

    tdiff_jumps = tdiff ~= mfdt; % uses median to avoid symmetric false positives
    info.non_uniform_sampling_indexes = find(tdiff_jumps);
    jval = tdiff(tdiff_jumps);
    has_jumps = ~isempty(jval);
    if has_jumps
        info.jump_magnitude = jval;
        if length(jval) > 1
            info.jump_forward_indexes = jval > 0;
            info.jump_backward_indexes = jval < 0;
            else

            if jval > 0
                info.jump_forward_indexes = find(tdiff == jval);
                info.jump_backward_indexes = [];
            else
                info.jump_forward_indexes = [];
                info.jump_backward_indexes = find(tdiff == jval);
            end

        end

    end

end
