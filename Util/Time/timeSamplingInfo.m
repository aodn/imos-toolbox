function [info] = timeSamplingInfo(time, prec)
    % function [info] = timeSamplingInfo(time, prec)
    %
    % Report information about a datenum time array given a time precision.
    % See Examples below to quantise time and to
    % allow (ignore) round ups (timescales).
    %
    % Inputs:
    %
    % time - a datenum time array
    % prec - a time precision string for time interval matching.
    %        Default to 'second', i.e.
    %        half-second or lower sampling is quantised/floored.
    %
    % Outputs:
    %
    % info - a structure with information regarding time sampling.
    %     .assumed_time_precision - the precision
    %     .constant_vector - if time is constant
    %     .number_of_sampling_steps - the number of different samplings at given precision
    %     .sampling_steps - the sampling periods in days
    %     .sampling_steps_in_seconds - ditto but in seconds
    %     .sampling_step_median - the most frequent value of the sampling dt
    %     .sampling_step_median_in_seconds - the most frequent value of the sampling dt
    %     .repeated_samples - if the time variable got repeated values
    %     .unique_sampling - if sampling intervals are unique
    %     .uniform_sampling - if sampling intervals are uniform
    %     .monotonic_sampling - if sampling are monotonic [incr/decr]
    %     .progressive_sampling - values are generally increasing
    %     .regressive_sampling - values are generally decreasing
    %     .non_uniform_sampling_indexes - left-most indexes of non-uniform sampling.
    %     .jump_magnitude - the index distance between the non-uniform  and the next uniform or non-uniform sampling
    %     .jump_forward_indexes - the indexes where positive non-uniform sampling is found
    %     .jump_backward_indexes - as above, but for negative sampling.
    %
    % Example:
    % % basic - ignore small drifts at requested scale
    %
    % info = timeSamplingInfo([1,2,3,4,5.3],'day');
    % assert(info.uniform_sampling);
    % assert(all([info.unique_sampling,info.monotonic_sampling,info.progressive_sampling]));
    %
    % % extra reports
    %
    % info = timeSamplingInfo([1,2,1,3,1,4,1,5,1],'day');
    % assert(~all([info.unique_sampling,info.progressive_sampling,info.regressive_sampling,info.monotonic_sampling]));
    % assert(isequal(info.sampling_steps_median,[]));
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

    tdiff = timeQuantisation(diff(time),prec);
    udt = unique(tdiff);
    nss = length(udt);

    info.number_of_sampling_steps = nss;
    info.sampling_steps = udt;
    info.sampling_steps_in_seconds = unique(timeQuantisation(tdiff*86400,'second'));

    mfdt = median(tdiff);
    tdiff_sign = sign(tdiff);
    mfdt_sign = median(tdiff_sign);
    tdiff_jumps = tdiff ~= mfdt;
    if find(mfdt == info.sampling_steps)
        info.sampling_steps_median = mfdt;
        info.sampling_steps_median_in_seconds = mfdt*86400;
    else
        info.sampling_steps_median = [];
        info.sampling_steps_median_in_seconds = [];
    end

    info.constant_vector = all(info.sampling_steps == 0);
    info.repeated_samples = info.sampling_steps(1) == 0;
    info.unique_sampling = isunique(time);
    info.uniform_sampling = info.number_of_sampling_steps == 1;
    info.monotonic_sampling = ~any(diff(tdiff_sign));
    info.progressive_sampling = mfdt_sign > 0;
    info.regressive_sampling = mfdt_sign < 0;

    jind = find(tdiff_jumps);

    if jind == 0
        info.non_uniform_sampling_indexes = [];
    else
        info.non_uniform_sampling_indexes = jind;
    end

    jval = tdiff(tdiff_jumps);

    no_jumps = isempty(jval);

    if no_jumps
        info.jump_magnitude = [];
        info.jump_forward_indexes = [];
        info.jump_backward_indexes = [];
    else
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
