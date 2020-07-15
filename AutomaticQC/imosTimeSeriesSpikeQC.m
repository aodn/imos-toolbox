function [timeseriesFlags, timeseriesLog] = imosTimeSeriesSpikeQC(sample_data, auto)
%function [varFlags, timeseriesLog] = imosTimeSeriesSpikeQC(sample_data,auto)
%
% The top-level function to initialize Spike Tests over timeSeries data.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   timeseriesFlags    - A variable named structure with flag values.
%
%   timeseriesLog   - A variable named structure with log values.
%
%
% author: hugo.oliveira@utas.edu.au
%

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

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if nargin < 2, auto = false; end

timeseriesFlags = struct();
timeseriesLog = struct();

is_profile = strcmp(readProperty('toolbox.mode'), 'profile');
time_ind = getVar(sample_data.dimensions, 'TIME');
time_missing = time_ind == 0;

if (is_profile || time_missing), return, end

has_burst_duration = (isfield(sample_data.meta, 'instrument_burst_duration') &&~isempty(sample_data.meta.instrument_burst_duration)) || (isfield(sample_data, 'instrument_burst_duration') &&~isempty(sample_data.instrument_burst_duration));
has_burst_interval = (isfield(sample_data.meta, 'instrument_burst_interval') &&~isempty(sample_data.meta.instrument_burst_interval)) || (isfield(sample_data, 'instrument_burst_interval') &&~isempty(sample_data.instrument_burst_interval));

has_burst = has_burst_duration || has_burst_interval;

if has_burst
    opts_file = ['AutomaticQC' filesep 'imosTimeSeriesSpikeQCBurst.txt'];
else
    opts_file = ['AutomaticQC' filesep 'imosTimeSeriesSpikeQC.txt'];
end

ts_variables = load_timeseries_variables(sample_data);

if isempty(ts_variables), return, end

postqc_data = gen_postqc(sample_data, ts_variables, has_burst);

if has_burst && numel(postqc_data.burst_index_range) == 1
    warning('Burst metadata not consistent with TIME variable...skipping')
    return
end

if auto
    user_interaction = struct();
    spike_methods = load_classifiers(opts_file, has_burst);
    method = readProperty(opts_file, 'auto_method');

    for k = 1:length(ts_variables)
        user_interaction.(ts_variables{k}) = spike_methods(method);
        user_interaction.(ts_variables{k}).spikes = [];
    end

else
    wobj = spikeWindow(postqc_data, ts_variables, opts_file, has_burst);
    uiwait(wobj.ui_window);
    user_interaction = wobj.UserData;
end

if isempty(user_interaction), return, end

selected_variables = fieldnames(user_interaction);

% process each variable received, if not already.
for k = 1:length(selected_variables)
    varname = selected_variables{k};

    postid = getVar(postqc_data.variables, varname);
    postqc_var = postqc_data.variables{postid};
    user_input = user_interaction.(varname);

    if isempty(user_input.spikes)%run now if preview was not triggered

        if has_burst
            user_input.spikes = user_input.fun(postqc_var.valid_burst_range, postqc_var.data, user_input.args{:});
        else
            user_input.spikes = user_input.fun(postqc_var.data, user_input.args{:});
        end

    end

    varid = getVar(sample_data.variables, varname);
    vardata = sample_data.variables{varid};

    %preview flag at "valid" index space
    %flag properly by shifting the indexes to full space.
    shifted_indexes = user_input.spikes + postqc_var.l - 1;

    qcSet = str2double(readProperty('toolbox.qc_set'));
    badFlag = imosQCFlag('spike', qcSet, 'flag');
    timeseriesFlags.(varname) = zeros(length(vardata.data), 1, 'int8');
    timeseriesFlags.(varname)(shifted_indexes, 1) = badFlag;
    timeseriesLog.(varname) = create_log(varname, user_input);
end

end

function [paramLog] = create_log(varname, user_input)
%function [paramLog] = create_log(varname, user_input)
%
% Construct the SpikeQC log strings for each variable
% and each parameters used.
%
nspikes = length(user_input.spikes);
fun_name = func2str(user_input.fun);
nargs = length(user_input.args);
arg_string = cell(1, nargs);

for l = 1:nargs - 1

    try
        arg_string{l} = [user_input.opts{l} '=' string(user_input.args{l}) ','];
    catch
        arg_string{l} = [user_input.opts{l} '=' func2str(user_input.args{l}) ','];
    end

end

arg_string{l + 1} = [user_input.opts{l + 1} '=' string(user_input.args{l + 1}) '.'];

paramLog = char(strjoin([sprintf('%s(%s,', fun_name, varname) arg_string{:}]));
end

function [ts_variables] = load_timeseries_variables(sample_data)
%function [ts_variables] = load_timeseries_variables(sample_data)
%
% Load only timeseries variable names from the toolbox cell of structs.
%

varnames = getSampleField(sample_data.variables, 'name');
ts_dims = getSampleField(sample_data.variables, 'dimensions');
c = 1;

for k = 1:length(ts_dims)

    if ~isempty(ts_dims{k}) &&~strcmpi(varnames{k}, 'DEPTH')
        ts_variables{c} = varnames{k};
        c = c + 1;
    end

end

end

function postqc = gen_postqc(sample_data, ts_variables, has_burst)
%function postqc = gen_postqc(sample_data, ts_variables)
%
% Construct a procqc data structure, the input for the SpikeQC window class.
% This extracts as all timeSeries from the structure, cut continuous invalid data and calculate the burst intervals, if any.
%
% Inputs:
%
% sample_data - the toolbox data struct.
% ts_variables - the time-series variables to process.
% has_burst - if the data is in burst-mode.
% 
% Outputs:
%
% postqc - A data structure that is a copycat of sample_data but with clean timeSeries variables only.
% postqc.variables{k}.name = The variable name.
% postqc.variables{k}.data = The data values.
% postqc.variables{k}.flags = The qcflags values of the variable.
% postqc.variables{k}.time = The time values.
% postqc.variables{k}.l - the first index of valid data (from continous invalid ones)
% postqc.variables{k}.r - the last index of valid data (ditto)
% postqc.variables{k}.valid_burst_range = the burst index ranges [only if has_burst is true]
%
%
% author: hugo.oliveira@utas.edu.au
%

postqc = struct();
n_ts_vars = numel(ts_variables);

timeId = getVar(sample_data.dimensions, 'TIME');
time = sample_data.dimensions{timeId}.data;

postqc.variables = cell(1, n_ts_vars);
postqc.dimensions = sample_data.dimensions;

if has_burst
    try
        burst_interval = sample_data.meta.instrument_burst_interval;
    catch
        burst_interval = sample_data.instrument_burst_interval;
    end

    postqc.burst_precision = precisionBounds(burst_interval / 86400);
    postqc.burst_index_range = findBursts(time, postqc.burst_precision);
end

for k = 1:n_ts_vars
    pqc_varname = ts_variables{k};
    pqc_id = getVar(sample_data.variables, pqc_varname);
    pqc_var = sample_data.variables{pqc_id};

    if find(pqc_var.flags > 2, 1)
        [l, r] = validBounds(pqc_var.flags);

        if isempty(l) && isempty(r)
            l = 1;
            r = length(pqc_var.flags);
        end

        postqc.variables{k}.name = pqc_varname;
        postqc.variables{k}.data = pqc_var.data(l:r);
        postqc.variables{k}.flags = pqc_var.flags(l:r);
        postqc.variables{k}.time = time(l:r);
        postqc.variables{k}.l = l;
        postqc.variables{k}.r = r;

        if has_burst
            postqc.variables{k}.valid_burst_range = findBursts(postqc.variables{k}.time, postqc.burst_precision);
        end

    else
        postqc.variables{k}.name = pqc_varname;
        postqc.variables{k}.data = pqc_var.data;
        postqc.variables{k}.flags = pqc_var.flags;
        postqc.variables{k}.time = time;
        postqc.variables{k}.l = 1;
        postqc.variables{k}.r = numel(pqc_var.data);
        if has_burst
            postqc.variables{k}.valid_burst_range = postqc.burst_index_range;
        end

    end
end

end

function [valid_burst_range, max_burst_len] = cut_burst_range(burst_index_ranges, l, r)
%function [valid_burst_range, max_burst_len] = cut_burst_range(burst_index_ranges, l, r)
% find the valid burst range and the maximum burst length
%
find_burst_ind = @(ind, x)(any(x == ind));
find_l = @(x)(find_burst_ind(l, x));
find_r = @(x)(find_burst_ind(r, x));
first_valid_burst = find(cellfun(find_l, burst_index_ranges));
last_valid_burst = find(cellfun(find_r, burst_index_ranges));

valid_burst_range = burst_index_ranges(first_valid_burst:last_valid_burst);

compute_burst_len = @(x)(max(x) - min(x));
max_burst_len = max(cellfun(compute_burst_len, valid_burst_range));
end
