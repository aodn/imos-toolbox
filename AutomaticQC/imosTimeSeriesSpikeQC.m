function [data, flags, paramsLog] = imosTimeSeriesSpikeQC(sample_data, data, k, type, auto)
%function [data, flags, paramsLog] = imosTimeSeriesSpikeQC( sample_data, data, k, type, auto )
%
% The top-level function to initialize Spike Tests over data.
% in and out water time.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   data        - the vector of data to check.
%
%   k           - Index into the sample_data.variables vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%   auto        - logical, run QC in batch mode
%
% Outputs:
%   data        - Same as input.
%
%   flags       - Vector the same size as data, with before in-water samples
%                 flagged.
%
%   paramsLog   - string containing details about params' procedure to include in QC log
%
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated
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
narginchk(4, 5);
if ~isstruct(sample_data), error('sample_data must be a struct'); end
if ~isscalar(k) ||~isnumeric(k), error('k must be a numeric scalar'); end
if ~ischar(type), error('type must be a string'); end

global apply_to_all_spike_qc
global button_action_spike_qc

% auto logical in input to enable running under batch processing
if nargin < 5, auto = false; end

paramsLog = [];
flags = [];

is_dimension_processing = strcmp(type, 'dimensions');

if is_dimension_processing
    return
else
    first_call = k == 1;
    if first_call
        apply_to_all_spike_qc = [];
        button_action_spike_qc = 'ok';
    else
        abort_requested = strcmpi(button_action_spike_qc, 'abort');
        if abort_requested
            return
        end
    end
end


default_opts_file = ['AutomaticQC' filesep 'imosTimeSeriesSpikeQC.txt'];
allowed_variables = strsplit(readProperty('allowed_variables', default_opts_file), ',');
allowed_variables = cellfun(@strtrim, allowed_variables, 'UniformOutput', false);

selected_variable = sample_data.variables{k}.name;

not_supported = ~contains(selected_variable, allowed_variables);
if not_supported
    return
end

has_burst = ~isempty(sample_data.instrument_burst_duration) ||~isempty(sample_data.instrument_burst_interval);

if has_burst
    warning('Spike burst processing not implemented yet')
    return
end

if strcmp(readProperty('toolbox.mode'), 'profile')
    warning('Spike profile processing not implemented yet')
    return
end

classifiers_visible_names = containers.Map;
classifiers_visible_names('Hampel') = load_hampel_opts(default_opts_file);
classifiers_visible_names('OTSU-Thresholding/despiking1') = load_otsu_threshold_opts(default_opts_file);
classifiers_visible_names('OTSU-Savgol/despiking2') = load_otsu_savgol_opts(default_opts_file);

%set defaults and ask user
if isempty(apply_to_all_spike_qc)
    [method_selected_in_popup,button_action_spike_qc] = init_popup(classifiers_visible_names, selected_variable);
    method = classifiers_visible_names(method_selected_in_popup);
else
    button_action_spike_qc = 'ok';
    method = classifiers_visible_names(apply_to_all_spike_qc);
end

bailout = ~strcmpi(button_action_spike_qc, 'ok') && ~isempty(button_action_spike_qc);
if bailout
    return
end

paramsLog = sprintf('imosTimeSeriesSpikeQC: %s method used', func2str(method.fun));
all_args = [data, method.args];
spikes = method.fun(all_args{:});

qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag = imosQCFlag('bad', qcSet, 'flag');
flags = zeros(length(data), 1, 'int8');
flags(spikes) = badFlag;

end

%ok variable can be processed - ask the user what to use.
function [method_selected_in_popup,button_action_spike_qc] = init_popup(method_dict, selected_variable)

method_selected_in_popup = 'Hampel'; % default and first to be shown
menu_options = keys(method_dict);
global apply_to_all_spike_qc

figure_opts = {
'Name', sprintf('imosToolbox: Spike QC test for %s', selected_variable), ...
    'Visible', 'on', ...
    'MenuBar', 'none', ...
    'Resize', 'on', ...
    'WindowStyle', 'Modal', ...
    'NumberTitle', 'on', ...
    };
figwindow = figure(figure_opts{:});

text_tip = uicontrol('Style', 'text', 'String', sprintf('Select the spike test for %s', selected_variable));
check_box = uicontrol('Style', 'checkbox');
popup = uicontrol(figwindow, ...
    'Style', 'popupmenu', ...
    'String', menu_options, ...
    'Callback', @menu_selection);

function apply_to_all(~, ~)
    if check_box.Value
        apply_to_all_spike_qc = method_selected_in_popup;
    else
        apply_to_all_spike_qc = [];
    end
end

function menu_selection(~, ~)
sval = popup.Value;
cstr = popup.String;
method_selected_in_popup = cstr{sval};
end

function abortTest(~, ~)
button_action_spike_qc = 'abort';
delete(figwindow)
end

function skipTest(~, ~)
button_action_spike_qc = 'skip';
delete(figwindow)
end

function confirmTest(~, ~)
button_action_spike_qc = 'ok';
delete(figwindow)
end

cancelButton = uicontrol(figwindow, 'Style', 'pushbutton', 'String', 'Abort', 'Callback', @abortTest, 'Position', [0, 0.0, 0.5, 0.1]);
skipButton = uicontrol(figwindow, 'Style', 'pushbutton', 'String', 'Skip', 'Callback', @skipTest, 'Position', [0., 0.0, 0.2, 0.2]);
confirmButton = uicontrol(figwindow, 'Style', 'pushbutton', 'String', 'Ok', 'Callback', @confirmTest, 'Position', [0.5, 0.0, 0.5, 0.1]);

state_list = {figwindow, check_box, text_tip, popup, cancelButton, skipButton, confirmButton};
normalize_units(state_list);

set(figwindow, 'Position', [0.3, 0.45, 0.4, 0.1]);
set(check_box, 'Position', [0.7, 0.32, 0.3, 0.3],'String','Apply to all variables','Callback',@apply_to_all); %[0.25,0.2,.3,.5]);
set(text_tip, 'Position', [0.23, 0.025, 0.3, 0.6]); %[0.25,0.2,.3,.5]);
set(popup, 'Position', [0.25, .25, .4, 0.25]);
set(cancelButton, 'Position', [0, 0, 0.2, 0.2]);
set(skipButton, 'Position', [0.2, 0., 0.6, 0.2]);
set(confirmButton, 'Position', [0.8, 0., 0.2, 0.2]);

waitfor(figwindow);

end

function [s] = load_hampel_opts(file)
s = struct();
read_func = @(x) str2func(readProperty(x, file));
read_numeric = @(x) str2double(readProperty(x, file));
s.fun = read_func('hampel_function');
opts = {'hampel_window', 'hampel_stdfactor'};
s.args = cellfun(read_numeric, opts, 'UniformOutput', false);
end

function [s] = load_otsu_savgol_opts(file)
s = struct();
read_func = @(x) str2func(readProperty(x, file));
read_numeric = @(x) str2double(readProperty(x, file));
s.fun = read_func('otsu_savgol_function');
opts = {'otsu_savgol_window', 'otsu_savgol_pdeg', 'otsu_savgol_nbins', 'otsu_savgol_oscale'};
s.args = cellfun(read_numeric, opts, 'UniformOutput', false);
end

function [s] = load_otsu_threshold_opts(file)
s = struct();
read_func = @(x) str2func(readProperty(x, file));
read_numeric = @(x) str2double(readProperty(x, file));
s.fun = read_func('otsu_threshold_function');
opts = {'otsu_threshold_nbins', 'otsu_threshold_oscale', 'otsu_threshold_centralize'};
s.args = cellfun(read_numeric, opts, 'UniformOutput', false);
s.args{end} = logical(s.args{end});
end

function normalize_units(items)

for k = 1:length(items)
    set(items{k}, 'Units', 'normalize');
end

end
