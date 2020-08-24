function [spikes] = imosSpikeClassifierBurstHampel(bindexes, signal, use_burst_window, half_window_width, madfactor, lower_mad_limit, repeated_only)
% function [spikes] = imosSpikeClassifierBurstHampel(bindexes, signal,  use_burst_window,  half_window_width, madfactor, lower_mad_limit, repeated_only)
%
% A Hampel classifier for burst data. The half_window_width is applied at burst level instead of
% sample level.
%
% Inputs:
%
% bindexes - a cell with the invidivudal burst range indexes.
% signal - A Burst 1-d signal.
% use_burst_window  - a boolean to consider the half_window_width applied at burst scale. If false, will consider the burst series as continuous.
% half_window_width - The half_window_width burst range (the full window size will be 1+2*half_window_width)
% madfactor -  A multipling scale for the MAD.
% repeated_only - a boolean to mark spikes in burst only if they are detected more than one time (only for half_window_width>0).
% lower_mad_limit - a lower threshold for the MAD values, which values below will be ignored.
%
% Outputs:
%
% spikes - An array with spikes indexes.
% fsignal - A filtered signal where the spikes are substituted by median values of the window.
%
% Example:
%
% % simple spikes
% x = randn(1,100)*1e-2;
% spikes = [3,7,33,92,99]
% x(spikes) = 1000;
% bduration = 6;
% v = 1:bduration:length(x)+bduration;
% for k=1:length(v)-1;
% bind{k} = [v(k),min(v(k+1)-1,length(x))];
% end
% [dspikes] = imosSpikeClassifierBurstHampel(bind,x);
% assert(isequal(dspikes,spikes));
% % equal to Hampel
% [dspikes] = imosSpikeClassifierBurstHampel(bind,x,length(bind));
% [dspikes2] = imosSpikeClassifierHampel(x,length(bind));
% assert(isequal(dspikes,spikes));
% assert(isequal(dspikes,dspikes2));
%
% % detecting entire burst as spike
% x = randn(1,100)*1e-2;
% fullburst_spiked = [3,7,13,14,15,16,17,18,33,92,99]
% x(fullburst_spiked) = 1000;
% [dspikes] = imosSpikeClassifierBurstHampel(bind,x);
% assert(isequal(dspikes,[3,7,33,92,99]));
% [dspikes2] = imosSpikeClassifierBurstHampel(bind,x,true,2);
% assert(isequal(dspikes2,fullburst_spiked))
%
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

narginchk(2, 7)

if nargin == 2
    use_burst_window = 0;
    half_window_width = 1;
    madfactor = 5;
    lower_mad_limit = 0;
    repeated_only = false;
elseif nargin == 3
    half_window_width = 1;
    madfactor = 5;
    lower_mad_limit = 0;
    repeated_only = false;
elseif nargin == 4
    madfactor = 5;
    lower_mad_limit = 0;
    repeated_only = false;
elseif nargin == 5
    lower_mad_limit = 0;
    repeated_only = false;
elseif nargin == 6
    repeated_only = false;
end

if ~use_burst_window
    if half_window_width == 0
        half_window_width = 1;
    end
    spikes = imosSpikeClassifierHampel(signal,half_window_width,madfactor,lower_mad_limit);
    return
end

nbursts = double(half_window_width) .* 2 + 1;
burst_is_series = nbursts >= length(bindexes);
if burst_is_series
    spikes = imosSpikeClassifierHampel(signal, ceil(length(signal)/2+1), madfactor,lower_mad_limit);
    return
end

spikes = NaN(size(signal));
%left bry
bs = 1;
range = 1:bindexes{nbursts}(end);
[bspikes] = imosSpikeClassifierHampel(signal(range), length(range), madfactor,lower_mad_limit);

if ~isempty(bspikes)
    blen = length(bspikes);
    spikes(bs:bs + blen - 1) = bspikes;
    bs = bs + blen;
end

h=[];
series_end_at_next_window = nbursts+1 >= length(bindexes)-nbursts;
if series_end_at_next_window
    bie = bindexes{nbursts+1}(1);
else
    sburst = 1;
    ni = nbursts+1;
    ne = length(bindexes)-nbursts;
    h=waitbar(0,'Computing Spikes');
    wbval=0;
    wbint=0.05;
    for eburst = ni:ne
        if eburst/ne > (wbval+wbint)
            wbval = wbval+wbint;
            waitbar(eburst/ne,h,'Computing Spikes');
        end
        sburst = sburst + 1;
        bis = bindexes{sburst}(1);
        bie = bindexes{eburst}(end);
        csignal = signal(bis:bie);
        [bspikes] = imosSpikeClassifierHampel(csignal, length(csignal), madfactor,lower_mad_limit);

        if ~isempty(bspikes)
            blen = length(bspikes);
            spikes(bs:bs + blen - 1) = bspikes + bis - 1;
            bs = bs + blen;
        end

    end
end
if ~isempty(h)
    h.delete()
end
%right bry
range = bie + 1:bindexes{end}(end);
[bspikes] = imosSpikeClassifierHampel(signal(range), length(range), madfactor,lower_mad_limit);

if ~isempty(bspikes)
    blen = length(bspikes);
    spikes(bs:bs + blen - 1) = bspikes + bie;
end

spikes = spikes(~isnan(spikes));
if repeated_only
    srange = min(spikes)-1:max(spikes)+1;
    candidates = find(histcounts(spikes,srange)>1);
    if ~isempty(candidates)
        spikes = candidates;
    end
else
    spikes = unique(spikes);
end


end
