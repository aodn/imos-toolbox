classdef test_SpikeClassifiers < matlab.unittest.TestCase

    properties (TestParameter)
        plot_figure = {true}; %,false};
    end

    methods (Test)

       function test_allf_for_single_large_spike_pass(~)
           signal = gen_spike_signal(1:1/24:10, [0.1, 10], [5, 1], 0, 0);
           signal(15) = signal(15) * std(signal) * 20;
           r_hampel = imosSpikeClassifierHampel(signal);
           r_otsu = imosSpikeClassifierOTSU(signal);
           r_savgol_otsu = imosSpikeClassifierNonBurstSavGolOTSU(signal);
           loc = unique([r_hampel,r_savgol_otsu]);
           assert(isequal(r_otsu,[14,15]));% otsu detects 2 no matter what because of differencing
           assert(isequal(loc, 15));
       end

       function test_allf_multiple_spikes_otsu_fails(~)
           signal = gen_spike_signal(1:1/24:10, [.1, 10], [5, 1], 0, 0);
           signal(15) = signal(15) * std(signal) * 10;
           signal(20) = signal(20) * std(signal) * 10;
           signal(30) = signal(30) * std(signal) * 10;
           r_hampel = imosSpikeClassifierHampel(signal);
           r_otsu = imosSpikeClassifierOTSU(signal);
           r_savgol_otsu = imosSpikeClassifierNonBurstSavGolOTSU(signal);
           assert(isequal(r_hampel, [15, 20, 30]))
           assert(isequal(r_savgol_otsu, [15, 20, 30]))
           assert(isequal(r_otsu, [20, 30])) % fails
       end

       function test_allf_multiple_spikes_similar_amplitude_savgol_fails(~)
           signal = gen_spike_signal(1:1/24:10, [10.1, 10], [5, 1], 0, 0);
           signal(15) = signal(15) * std(signal) * 10;
           signal(20) = signal(20) * std(signal) * 10;
           signal(30) = signal(30) * std(signal) * 10;
           r_hampel = imosSpikeClassifierHampel(signal);
           r_otsu = imosSpikeClassifierOTSU(signal);
           r_savgol_otsu = imosSpikeClassifierNonBurstSavGolOTSU(signal);
           assert(isequal(r_hampel, [15, 20, 30]))
           assert(~isequal(r_otsu, [15, 20, 30]))
           assert(isequal(r_otsu, [20, 30]))% incomplete detection
           assert(~isequal(r_savgol_otsu, [15, 20, 30]))
           assert(isequal(r_savgol_otsu, [20, 30])) % incomplete detection
       end

       function test_allf_multiple_spikes_with_different_stds_hampel_pass(~)
           signal = gen_spike_signal(1:1/24:10, [10.1, 10], [5, 1], 0, 0);
           signal(15) = signal(15) * std(signal) * 10;
           signal(20) = signal(20) * std(signal) * 5;
           signal(30) = signal(30) * std(signal) * 1;
           r_hampel = imosSpikeClassifierHampel(signal);
           r_otsu = imosSpikeClassifierOTSU(signal);
           r_savgol_otsu = imosSpikeClassifierNonBurstSavGolOTSU(signal);
           assert(isequal(r_hampel, [15, 20, 30]))
           assert(~isequal(r_otsu, [15, 20, 30]))
           assert(~isequal(r_savgol_otsu, [15, 20, 30]))
           % there are no parameters available to mark the spikes exactly
       end

       function test_allf_multiple_spikes_with_different_stds_hampel_fails(~)
           signal = gen_spike_signal(1:1/24:10, [10.1, 10], [5, 1], 0, 0);
           signal(15) = signal(15) * std(signal) * 1;
           signal(20) = signal(20) * std(signal) * 1;
           signal(30) = signal(30) * std(signal) * 1;
           r_hampel = imosSpikeClassifierHampel(signal);
           r_otsu = imosSpikeClassifierOTSU(signal);
           r_savgol_otsu = imosSpikeClassifierNonBurstSavGolOTSU(signal);
           assert(~isequal(r_hampel, [15, 20, 30]))
           assert(~isequal(r_otsu, [15, 20, 30]))
           assert(~isequal(r_savgol_otsu, [15, 20, 30]))
           % feasible solution - reduce the standard deviation factor to detect lower
           % variability spikes
           r_hampel = imosSpikeClassifierHampel(signal, 3, 1);
           assert(isequal(r_hampel, [15, 20, 30]));
           % solution is feasible even with different windows, since signal is simple
           r_hampel = imosSpikeClassifierHampel(signal, 6, 1);
           assert(isequal(r_hampel, [15, 20, 30]));
           % However, one needs to know the approximate scale of the spike noise
           % or it will overflow return false positives.
           r_hampel = imosSpikeClassifierHampel(signal, 12, 1);
           assert(~isequal(r_hampel, [15, 20, 30]));
       end

       function test_hampel_robust_in_multi_spike_detection(~, plot_figure)
           time = 0:1/24:10;
           nspikes = 25;
           mfac = 5;
           [osig, ssig, spikes] = gen_spike_signal(time, [0.2, 8, 2], [1/24, 5, 30], nspikes, mfac);
           hs = imosSpikeClassifierHampel(ssig, nspikes / 5, mfac * 1.2);

           nbins = maximize_otsu_threshold(ssig);
           os = imosSpikeClassifierOTSU(ssig, nbins);
           ss = imosSpikeClassifierNonBurstSavGolOTSU(ssig, nspikes / 5, 2, nbins);

           assert(isequal(hs, spikes))
           assert(~isequal(os, spikes))
           assert(~isequal(ss, spikes))

           if plot_figure
               plot_spikes(time, osig, ssig, spikes, hs)
               title('Simple spike detection - Hampel')
               hold on
               plot_spikes(time, osig, ssig, spikes, os)
               title('Simple spike detection - OTSU')
               plot_spikes(time, osig, ssig, spikes, ss)
               title('Simple spike detection - Savgol-OTSU')

           end

       end

       function test_OTSU_noise_spike_detection_is_incomplete(~, plot_figure)
           time = 0:1/24:10;
           nspikes = 25;
           mfac = 1;
           [osig, ssig, spikes] = gen_spike_signal(time, [20, 5, 20, 1], [4/24, 12/24, 5, 30], nspikes, mfac);
           dspikes = imosSpikeClassifierOTSU(ssig);

           if plot_figure
               plot_spikes(time, osig, ssig, spikes, dspikes)
               title('Incomplete Spike Detection - False Positives - OTSU')
           end

           matches = intersect(dspikes, spikes);
           incomplete_detection = length(matches) < length(spikes);
           ratio_detection = length(matches) / length(spikes);
           false_positives = ~isempty(setdiff(dspikes, spikes));
           assert(incomplete_detection)
           assert(ratio_detection > 0.5)
           assert(false_positives)
           assert(length(dspikes) == 16)
       end

       function test_hampel_noise_spike_detection_incomplete(~, plot_figure)
           time = 0:1/24:10;
           nspikes = 25;
           mfac = 1;
           [osig, ssig, spikes] = gen_spike_signal(time, [20, 5, 20, 1], [4/24, 12/24, 5, 30], nspikes, mfac);
           dspikes = imosSpikeClassifierHampel(ssig);

           if plot_figure
               plot_spikes(time, osig, ssig, spikes, dspikes)
               title('Incomplete Spike Detection - Hampel')
           end

           matches = intersect(dspikes, spikes);
           incomplete_detection = length(matches) < length(spikes);
           ratio_detection = length(matches) / length(spikes);
           no_false_positives = isempty(setdiff(dspikes, spikes));
           assert(incomplete_detection)
           assert(ratio_detection < 0.5)
           assert(no_false_positives)
           assert(length(dspikes) == 9)

       end

       function test_savgolOTSU_noise_spike_detection_has_false_positives(~, plot_figure)
           time = 0:1/24:10;
           nspikes = 25;
           mfac = 1;
           [osig, ssig, spikes] = gen_spike_signal(time, [20, 5, 20, 1], [4/24, 12/24, 5, 30], nspikes, mfac);
           dspikes = imosSpikeClassifierNonBurstSavGolOTSU(ssig);

           if plot_figure
               plot_spikes(time, osig, ssig, spikes, dspikes)
               title('Incomplete Spike Detection - with False positives - SavGol-OTSU')
           end

           matches = intersect(dspikes, spikes);
           incomplete_detection = length(matches) < length(spikes);
           ratio_detection = length(matches) / length(spikes);
           false_positives = ~isempty(setdiff(dspikes, spikes));
           assert(incomplete_detection)
           assert(ratio_detection > 0.5)
           assert(false_positives)
           assert(length(dspikes) == 18)
       end

       function test_hampel_under_detection_false_positives(~, plot_figure)
           time = 0:1/24:10;
           nspikes = 25;
           mfac = 1;
           [osig, ssig, spikes] = gen_spike_signal(time, [20, 5, 20, 1], [4/24, 12/24, 5, 30], nspikes, mfac);
           dspikes = imosSpikeClassifierHampel(ssig, 6, mfac * 1.2); %

           if plot_figure
               plot_spikes(time, osig, ssig, spikes, dspikes)
               title('Incomplete Spike detection - Hampel method')
           end

           matches = intersect(dspikes, spikes);
           incomplete_detection = length(matches) < length(spikes);
           ratio_detection = length(matches) / length(spikes);
           false_positives = ~isempty(setdiff(dspikes, spikes));
           nfalse = length(setdiff(dspikes, spikes));
           assert(incomplete_detection)
           assert(ratio_detection > 0.9)
           assert(false_positives)
           assert(length(dspikes) == 44)
           assert(length(nfalse) == 1)
       end

        function test_bursthampel(~,plot_figure)
            samples_per_burst = 60;
            burst_sampling = 1/86400;
            burst_interval = 3600/86400;
            bind = {[1,60], [61,120], [121,180],[181,240]};
            time = [0:1:59, 3600:1:3659, 7200:1:7259, 10800:1:10859];
            osig = [12+randc(1,60),12+randc(1,60),18+randc(1,60),18+randc(1,60)];
            ssig = osig;
            spikes = 121;
            ssig(spikes) = 25;
            use_burst_window = true;
            window = 0; % single burst
            madfactor = 5;
            dspikes = imosSpikeClassifierBurstHampel(bind,ssig,use_burst_window,window,madfactor);
            if plot_figure
                plot_spikes(time, osig, ssig, spikes, dspikes)
                title('Spike in burst detection - Burst Hampel method')
            end
            assert(isequal(dspikes,spikes));
            %entire burst as spike
            spikes = 121:180;
            ssig(spikes) = 25;
            window = 1; % 3 bursts choosen <b-1><b><b+1>, total of 180 samples
            dspikes = imosSpikeClassifierBurstHampel(bind,ssig,use_burst_window,window,madfactor);
            if plot_figure
                plot_spikes(time, osig, ssig, spikes, dspikes)
                title('Entire Burst as spike detection - Burst Hampel method')
            end
            assert(isequal(dspikes,spikes));
        end

        function test_burststats(~,plot_figure)
            samples_per_burst = 60;
            burst_sampling = 1/86400;
            burst_interval = 3600/86400;
            bind = {[1,60], [61,120], [121,180],[181,240]};
            time = [0:1:59, 3600:1:3659, 7200:1:7259, 10800:1:10859];
            osig = [12+randc(1,60),12+randc(1,60),18+randc(1,60),18+randc(1,60)];
            ssig = osig;
            spikes = 121;
            ssig(spikes) = 25;
            dspikes = imosSpikeClassifierBurstRunningStats(bind,ssig);
            assert(isequal(dspikes,spikes));
            spikes = 121:125;
            ssig(spikes) = 25;
            dspikes = imosSpikeClassifierBurstRunningStats(bind,ssig);
            assert(isequal(dspikes,spikes));
        end

    end

end

function [osig, ssig, spikes] = gen_spike_signal(time, amps, periods, nspikes, stdmag)
% function e = gen_spike_signal()
%
% Generate a periodic signal with fixed interval and
% a fixed number of randomized spikes with amplitude proportional to stdmag and
% the distribution of the amplitudes provided.
%
% Inputs:
% time - a time range, time series, or sorted datenum array.
%        The smallest time interval is used for generation.
% amps - a vector with normalized signal amplitudes.
% periods - a vector with the signal period (days).
% nspikes - the number of spikes to introduce.
%           If missing, the number of spikes is a
%           random number between 0 and half the length of the time vector.
% stdmag - a standard deviation scale for the spike.
%
% Outputs:
%
% osig  - the clean signal.
% ssig - the spiked signal.
% spikes - the location of the spikes.
%
% author: hugo.oliveira@utas.edu.au
%

rng(0, 'simdTwister'); %simd is faster

if length(amps) ~= length(periods)
    error("Amplitude and Periods shou should be the same length")
end

dts = timeQuantisation(unique(diff(time)), 'second');
dt = dts(1);
stime = 0:dt:max(time);
osig = zeros(size(stime));

if nargin < 4
    nspikes = randi([0, floor(length(stime) / 2)]);
    stdmag = 1;
end

[~, time_ind] = intersect(stime, time);

for k = 1:length(amps)
    a = amps(k);
    omega = 2 * pi / periods(k);
    osig = osig + a * cos(omega * stime);
end

if nspikes == 0
    return
end

spikes = 0;

while length(spikes) ~= nspikes
    spikes = unique(randi([1, length(time_ind)], 1, nspikes));
end

if length(amps) > 1
    rmax = max(amps) * std(amps) * stdmag;
    rmin = -1 * min(amps) * std(amps) * stdmag;
else
    rmax = amps(1) * stdmag;
    rmin = -1 * rmax;
end

spike_mag = abs(rmin) - (rmax - rmin) * rand(1, nspikes);
osig = osig(time_ind);
ssig = osig;
ssig(spikes) = ssig(spikes) + spike_mag;

end

function plot_spikes(time, osig, ssig, spikes, dspikes)
figure();
plot(time, ssig, 'r')
hold on
plot(time, osig, 'b')
plot(time(spikes), ssig(spikes), 'rs')
plot(time(dspikes), ssig(dspikes), 'k*')
legend('spiked signal', 'clean signal', 'real spikes', 'detected spikes')
end

function nbins = maximize_otsu_threshold(signal)
ot = 0;
nbins = 0;

for k = 1:512
    new_ot = abs(otsu_threshold(signal, k));

    if new_ot > ot
        ot = new_ot;
        nbins = k;
    end

end

end
