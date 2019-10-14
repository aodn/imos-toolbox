function [newtime] = fixRepeatedTimesJFE(time),
    % function newtime = fixRepeatedTimesJFE(time),
    %
    % Add the missing miliseconds to the repeated
    % date numbers in the time array based on their
    % ordering and the number of repeated entries.
    %
    % Problem:
    % The date number entries when reading JFE inifinity
    % instrument dat files are precision clipped.
    %
    % Scope:
    % Required fix when the insturment is set for
    % sub-second sampling and reporting.
    %
    % Inputs:
    %
    % time - the entire time vector read from the instrument file
    %        in days
    %
    % Outputs:
    %
    % newtime - the new time values with miliseconds accounted for.
    %
    % Example:
    % sbase = 1/86400;
    % fmt = 'MM:SS.FFF';
    % vstart = repmat(sbase,1,3);
    % vmid = repmat(2*sbase,1,10);
    % vjump = repmat(15*60*sbase,1,10);
    % vend = repmat(16*60*sbase,1,5);
    % time = horzcat(vstart,vmid,vjump,vend);
    % [newtime] = fixRepeatedTimesJFE(time);
    % assert(strcmpi('00:01.700',datestr(newtime(1),fmt)));
    % assert(strcmpi('00:01.900',datestr(newtime(3),fmt)));
    % assert(strcmpi('00:02.000',datestr(newtime(4),fmt)));
    % assert(strcmpi('00:02.900',datestr(newtime(13),fmt)));
    % assert(strcmpi('15:00.000',datestr(newtime(14),fmt)));
    % assert(strcmpi('15:00.100',datestr(newtime(15),fmt)));
    % assert(strcmpi('15:00.900',datestr(newtime(23),fmt)));
    % assert(strcmpi('16:00.000',datestr(newtime(24),fmt)));
    % assert(strcmpi('16:00.400',datestr(newtime(end),fmt)));
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

    tlen = length(time);
    tsize = size(time);
    not_a_vector = tsize(1) ~= 1 && tsize(2) ~= 1;

    if not_a_vector,
        error('argument not a vector')
    end

    if ~issorted(time),
        error('time is not sorted')
    end

    tinfo = timeSamplingInfo(time);

    if tinfo.constant_vector,
        error('time is a constant vector')
    end

    if tinfo.unique_sampling,
        newtime = time;
        return
    end

    if ~tinfo.repeated_samples,
        newtime = time;
        return
    end

    %repeats + burst sampling + burst interval
    % 0      + dt             +  dt*n
    if tinfo.sampling_steps > 3
        error('Vector contains more than 3 sampling frequencies')
    end

    newtime = zeros(tsize);

    freq = tinfo.sampling_steps(2); % sampling_steps is sorted

    [ritem, nrepeats, rstart, rend] = findRepeats(time);

    nur = unique(nrepeats);
    % use maximum number of repeats for interval correction
    maxrepeat = max(nur);

    % allow only the start and end of a series to have different
    % len of repeats.
    wildly_repeated = length(nur) > 3;

    if wildly_repeated,
        msg = sprintf('Number of different repeats is too big %d', nur);
        error(msg);
    end

    partial_time = @(freq, nr) freq * (0:nr - 1) / nr;

    %boundary conditions
    ztime = partial_time(freq, maxrepeat);
    stime = ztime(end - nrepeats(1) + 1:end);
    etime = ztime(1:nrepeats(end));
    newtime(rstart(1):rend(1)) = stime;
    newtime(rstart(end):rend(end)) = etime;

    for k = 2:length(rstart) - 1
        is = rstart(k);
        ie = rend(k);
        ilen = nrepeats(k);
        ztime = partial_time(freq, ilen);
        newtime(is:ie) = ztime;
    end

    newtime = newtime + time;

end
