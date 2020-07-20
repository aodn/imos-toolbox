%Use toolbox to process single ping ADCP data.
% problem with current version of toolbox is that the plotting of
% single-ping data has a huge time overhead. Goal is to use the toolbox as
% much as possible to get the data processed, but avoid the plotting until
% the end - or all together.
%
% Bec Cowley, May/June, 2020
%Have updated workhorseParse to do beam to ENU conversion

% Set up:
clear
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
toolboxVersion = ['2.6.6 - ' computer];
auto = false;
iMooring = [];
nonUTCRawData = importManager(toolboxVersion, auto, iMooring);


% add an index field to each data struct
for k = 1:length(nonUTCRawData), nonUTCRawData{k}.meta.index = k; end

%% preprocess data
[ppData, cancel] = preprocessManager(nonUTCRawData, 'qc', mode, false);
if cancel
    rawData = nonUTCRawData;
else
    rawData = preprocessManager(nonUTCRawData, 'raw',  mode, true);  % only apply TIME to UTC conversion pre-processing routines, auto is true so that GUI only appears once
end

% save data set selection
setIdx = 1:length(ppData);

%% Determine thresholds using some low-overhead plots:
adcpThresholds
return
%% Run autoQC tests, apply selected thresholds here:
% do one at a time so that the results plot shows the fails for each
% individual test.
% run QC routines over raw data
aqc = autoQCManager(ppData(setIdx));

% if user interrupted process, return either pre-processed data (if no QC performed yet) or old QC data
if isempty(aqc)
    aqc = autoQCData(setIdx);
end

% otherwise return new QC data
autoQCData(setIdx) = aqc;

%set the qclevel flag so we are forced to load the historicalQCdataset in
%GUI
for Idx = 1:length(setIdx)
    autoQCData{Idx}.meta.level = 0;
end
% now review the results of the flags applied with each test
% comment out as required
% adcpThresholdsResults(autoQCData,'surfacetest')
adcpThresholdsResults(autoQCData,'echorange')
% adcpThresholdsResults(autoQCData,'erv')
% adcpThresholdsResults(autoQCData,'cmag')
% adcpThresholdsResults(autoQCData,'echo')

%% now we have the thresholds, run the toolbox as is, with the values determined.
% need to delete the pqc file for the RDIs before doing the imos toobox as
% I think that the values in pqc are overwriting edits in the
% configuration. need to check. YES, BUG/

%Next step, export to single ping netcdf and then re-import to matlab, bin
%average and stack.