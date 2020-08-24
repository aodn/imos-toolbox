function [cmap] = loadSpikeClassifiers(file, is_data_burst)
%function [cmap] = loadSpikeClassifiers(file, is_data_burst)
%
% Load all SpikeQC classifiers parameters and options as a dict.
%
% Input:
%
% file - the parameter txt file
% is_data_burst - boolean for loading burst Classifiers.
%
% Output:
%
% cmap - the classifier dictionary
% cmap.fun - the function handler for the test @f(data,varargin{:})
% cmap.opts - cell of strings containing the parameter arguments names
% cmap.args - cell with different parameter arguments types/values.
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
cmap = containers.Map;

if is_data_burst
    cmap('Hampel-Burst') = load_bursthampel_opts(file);
    cmap('Running-Statistics/imosBurstQC') = load_runningstats_opts(file);
else
    cmap('Hampel') = load_hampel_opts(file);
    cmap('OTSU-Thresholding/despiking2') = load_otsu_threshold_opts(file);
    cmap('OTSU-Savgol/despiking1') = load_otsu_savgol_opts(file);
end

end

function [func] = read_func(file, name)
func = str2func(readProperty(name, file));
end


function [newargs] = typed_args(argnames, args)
%function [newargs] = typed_args(argnames, args, npoints)
%
% typecast the args based on their limit types.
%
newargs = cell(size(args));
limits = imosSpikeClassifiersLimits(1);

for n = 1:length(argnames)
    name = argnames{n};
    typefun = str2func(class(limits.(name).min));
    newargs{n} = typefun(args{n});
end

end

function [s] = load_hampel_opts(file)
%function [s] = load_hampel_opts(file)
s = struct();
s.fun = read_func(file, 'hampel_function');
s.opts = {'hampel_half_window_width', 'hampel_madfactor','hampel_lower_mad_limit'};
read_number = @(name)(str2double(readProperty(name, file)));
rawargs = cellfun(read_number, s.opts, 'UniformOutput', false);
s.args = typed_args(s.opts, rawargs);
end

function [s] = load_otsu_savgol_opts(file)
%function [s] = load_otsu_savgol_opts(file)
s = struct();
s.fun = read_func(file, 'otsu_savgol_function');
s.opts = {'otsu_savgol_window', 'otsu_savgol_pdeg', 'otsu_savgol_nbins', 'otsu_savgol_oscale'};
read_number = @(name)(str2double(readProperty(name, file)));
rawargs = cellfun(read_number, s.opts, 'UniformOutput', false);
s.args = typed_args(s.opts, rawargs);
end

function [s] = load_otsu_threshold_opts(file)
%function [s] = load_otsu_threshold_opts(file)
s = struct();
s.fun = read_func(file, 'otsu_threshold_function');
s.opts = {'otsu_threshold_nbins', 'otsu_threshold_oscale', 'otsu_threshold_centralise'};
read_number = @(name)(str2double(readProperty(name, file)));
rawargs = cellfun(read_number, s.opts, 'UniformOutput', false);
s.args = typed_args(s.opts, rawargs);
end

function [s] = load_bursthampel_opts(file)
%function [s] = load_bursthampel_opts(file)
s = struct();
s.fun = read_func(file, 'burst_hampel_function');
s.opts = {'burst_hampel_use_burst_window','burst_hampel_half_window_width','burst_hampel_madfactor', 'burst_hampel_lower_mad_limit', 'burst_hampel_repeated_only'};
read_number = @(name)(str2double(readProperty(name, file)));
rawargs = cellfun(read_number, s.opts, 'UniformOutput', false);
s.args = typed_args(s.opts, rawargs);
end

function [s] = load_runningstats_opts(file)
%function [s] = load_runningstats_opts(file)
s = struct();
s.fun = read_func(file, 'burst_runningstats_function');
s.opts = {'burst_runningstats_scalefun','burst_runningstats_dispersionfun','burst_runningstats_dispersion_factor'};
read_number = @(name)(str2double(readProperty(name, file)));
s.args = {read_func(file,s.opts{1}),read_func(file,s.opts{2}),read_number(s.opts{3})};
end
