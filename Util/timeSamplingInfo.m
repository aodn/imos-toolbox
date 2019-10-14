function [info] = timeSamplingInfo(t, prec),
    % function [info] = timeSamplingInfo(t)
    %
    % Report information about a
    % time array t, usually
    % the returned value of datenum.
    %
    % Inputs:
    %
    % t - an array with numerical values
    % prec - a time precision string for
    %        time interval matching.
    %        Default to 'milisecond'.
    %
    % Outputs:
    %
    % info - a structure with information regarding time sampling.
    %     .sampling_steps - the sampling periods
    %     .sampling_steps_median - the median of the sampling dt
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
    %
    % info = timeSamplingInfo([1,2,3,4]);
    % assert(info.uniform_sampling);
    % assert(all([info.unique_sampling,info.monotonic_sampling,info.progressive_sampling]));
    %
    % info = timeSamplingInfo([1,2,1,3,1,4,1,5,1]);
    % assert(~all([info.unique_sampling,info.progressive_sampling,info.regressive_sampling,info.monotonic_sampling]));
    % assert(isequal(info.sampling_steps_median,[]));
    % assert(all(info.jump_forward_indexes==[1 0 1 0 1 0 1 0]));
    % assert(all(info.jump_backward_indexes==[0 1 0 1 0 1 0 1]));
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
    if nargin < 2,
        prec = 'milisecond';
    end

    switch prec
        case 'day'
            tequalizer = 1;
        case 'hour'
            tequalizer = 24;
        case 'second'
            tequalizer = 86400;
        case 'milisecond'
            tequalizer = 86400 * 1e3;
        case 'microsecond'
            tequalizer = 86400 * 1e6;
    end

    tdiff = diff(round(t * tequalizer, 0)) / tequalizer;

    sampling_steps = unique(tdiff);
    constant_vector = all(sampling_steps == 0);
    repeated_samples = sampling_steps(1) == 0;

    mfdt = median(tdiff);

    tdiff_sign = sign(tdiff);
    mfdt_sign = median(tdiff_sign);

    tdiff_jumps = tdiff ~= mfdt;

    info = struct();
    info.constant_vector = constant_vector;
    info.sampling_steps = sampling_steps;
    info.repeated_samples = repeated_samples;

    if find(mfdt == info.sampling_steps),
        info.sampling_steps_median = mfdt;
    else
        info.sampling_steps_median = [];
    end

    info.unique_sampling = isunique(t);
    info.uniform_sampling = length(info.sampling_steps) == 1;
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

    if no_jumps,
        info.jump_magnitude = [];
        info.jump_forward_indexes = [];
        info.jump_backward_indexes = [];
    else
        info.jump_magnitude = jval;

        if length(jval) > 1,
            info.jump_forward_indexes = jval > 0;
            info.jump_backward_indexes = jval < 0;
            else,

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
