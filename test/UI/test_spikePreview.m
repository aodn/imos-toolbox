classdef test_spikePreview < matlab.unittest.TestCase

    methods (Test)

        function test_abort_is_empty(~)
            [postqc_data] = gen_postqc_data;
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierOTSU;
            spikeqc.opts = {'otsu_threshold_nbins', 'otsu_threshold_oscale', 'otsu_threshold_centralise'};
            spikeqc.args = {int64(100), 1.0, true};
            z = previewWindow(postqc_data, 'otsu_threshold', spikeqc);
            disp('interact but click Abort at the end')
            uiwait(z.ui_window);
            assert(isempty(fieldnames(z.UserData)))
        end

        function test_otsu_threshold(~)
            [postqc_data] = gen_postqc_data;
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierOTSU;
            spikeqc.opts = {'otsu_threshold_nbins', 'otsu_threshold_oscale', 'otsu_threshold_centralise'};
            spikeqc.args = {int64(100), 1.0, true};
            z = previewWindow(postqc_data, 'otsu_threshold', spikeqc);
            disp('select nbins=50, scale=0.8 and centralize=1')
            uiwait(z.ui_window);
            assert(isequal(z.UserData.args, {50, 0.8, 1}));
        end

        function test_otsu_savgol(~)
            [postqc_data] = gen_postqc_data();
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierNonBurstSavGolOTSU;
            spikeqc.opts = {'otsu_savgol_window', 'otsu_savgol_pdeg', 'otsu_savgol_nbins', 'otsu_savgol_oscale'};
            spikeqc.args = {int64(5), 2.0, int64(100), 1.};
            z = previewWindow(postqc_data, 'otsu_savgol', spikeqc);
            disp('Select window=10, pdeg=3, nbins=3, and scale=0.2');
            uiwait(z.ui_window)
            assert(isequal(z.UserData.args, {int64(10), 3, int64(3), 0.2}));
        end

        function test_hampel(~)
            [postqc_data] = gen_postqc_data();
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierHampel;
            spikeqc.opts = {'hampel_half_window_width', 'hampel_madfactor', 'hampel_lower_mad_limit'};
            spikeqc.args = {int64(6), 1.0, 0.0};
            z = previewWindow(postqc_data, 'hampel', spikeqc);
            disp('Select half-window=2, madfactor=1, madlimit=0.01');
            uiwait(z.ui_window)
            assert(isequal(z.UserData.args, {2, 1, 0.01}));
        end

        function test_burst_hampel(~)
            [postqc_data] = gen_burst_data();
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierBurstHampel;
            spikeqc.opts = {'burst_hampel_use_burst_window', 'burst_hampel_half_window_width', 'burst_hampel_madfactor', 'burst_hampel_lower_mad_limit', 'burst_hampel_repeated_only'};
            spikeqc.args = {0, int64(6), 1.0, 0.0, false};
            z = previewWindow(postqc_data, 'bursthampel', spikeqc);
            disp('Select burst_hampel_use_burst_window=1,hampel_half_window_width=1, madfactor=3, madlimit=0.01, repeated_only=0');
            uiwait(z.ui_window)
            assert(isequal(z.UserData.args, {1, 1, 3, 0.01, 0}));
        end

        function test_burst_runningstats(~)
            [postqc_data] = gen_burst_data();
            spikeqc = struct();
            spikeqc.fun = @imosSpikeClassifierBurstRunningStats;
            spikeqc.opts = {'burst_runningstats_scalefun', 'burst_runningstats_dispersionfun', 'burst_runningstats_dispersion_factor'};
            spikeqc.args = {@nanmean, @nanstd, 1.0};
            z = previewWindow(postqc_data, 'runningstats', spikeqc);
            disp('Select scalefun=nanmedian, dispersionfun=mad, dispersion_factor=5')
            uiwait(z.ui_window)
            scalefun = z.UserData.args{1};
            dispersionfun = z.UserData.args{2};
            dispersionfactor = z.UserData.args{3};
            assert(scalefun([NaN, 1, 1]) == 1);
            assert(dispersionfun([NaN, 0, 0]) == 0);
            assert(dispersionfactor == 5);
        end

    end

end

function [time, tsignal] = gen_signal()
time = 0:3600:(86400 * 10);
omegas = [2*pi/(3600*3) 2*pi/(3600*12) 2*pi/(3600*24*2)];
amps = [0.15 12 0.6];
tsignal = 1 ./ time + amps(1) .* cos(omegas(1) * time) + amps(2) .* cos(omegas(2) * time) + amps(3) .* cos(omegas(3) * time);
spike = @(x, y)(sign(x) .* abs(x).^y);
tsignal(100) = spike(tsignal(100), 1.5);
tsignal(200) = spike(tsignal(100), 1.8);
tsignal(201) = -1 * spike(tsignal(201), 1.8);
tsignal(205) = -1 * spike(tsignal(201), 1.5);
time = 1/86400 * time;
end

function [bind, time, tsignal] = gen_burst_signal()
%just space the signal
[t, tsignal] = gen_signal();
xs = 1:6:length(t);
xe = [xs(2:end)-1 length(t)];
dt = 30;
ds = 1800;

time = t*0;
bstep = 0:dt:(dt*(xe(1)-xs(1)));
time(xs(1):xe(1)) = bstep;
bind = cell(1, length(xs));
bind{1} = [xs(1), xe(1)];
for k = 2:length(xs)
    bstep = 0:dt:(dt*(xe(k)-xs(k)));
    time(xs(k):xe(k)) = time(xs(k-1))+ds*(k-1)+bstep;
    bind{k} = [xs(k), xe(k)];
end
time = 1/86400 .* time;
end

function [postqc_data] = gen_postqc_data()
[time, tsignal] = gen_signal();
postqc_data = struct('name', 'TEMP', 'data', tsignal,'time',time,'l',1,'r',length(tsignal));
end

function [postqc_data] = gen_burst_data()
[bind, time, tsignal] = gen_burst_signal();
postqc_data = struct('name', 'TEMP', 'data', tsignal, 'time', time,'l',1,'r',length(tsignal),'valid_burst_range',{bind}); 
end
