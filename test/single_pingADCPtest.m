%Use toolbox to process single ping ADCP data.
% problem with current version of toolbox is that the plotting of
% single-ping data has a huge time overhead. Goal is to use the toolbox as
% much as possible to get the data processed, but avoid the plotting until
% the end - or all together.
%
% Bec Cowley, May/June, 2020
%Have updated workhorseParse to do beam to ENU conversion
% 2021: adapted to review screening of single-ping data with fish detection
% and correlation magnitude

% Set up:
clear
  % get the toolbox execution mode
  mode = readProperty('toolbox.mode');
toolboxVersion = ['2.6.13 - ' computer];
auto = false;
iMooring = [];
nonUTCRawData = importManager(toolboxVersion, auto, iMooring);
%% first do mapping and an ENU conversion so we can see velocities in the screening plots
%run using the pp window to ensure flags are handled properly;
% run these routines:
% adcpBinMappingPP
% adcpWorkhorseCorrMagPP - RDI recommended threshold = 64
% adcpWorkhorseEchoRangePP - RDI recommended threshold = 50
% adcpWorkhorseVelocityBeam2EnuPP
for k = 1:length(nonUTCRawData), nonUTCRawData{k}.meta.index = k; end
% preprocess data
 [sden, cancel] = preprocessManager(nonUTCRawData, 'qc', mode, false); 
% magneticDeclinationPP
%% Determine thresholds using some low-overhead plots:

%first check the single-ping screening thresholds (echo range and
%corrMagPP)
% If these are not suitable, need to adjust in the pp step (next cell).
% Might need to delete the *.ppp files in the raw_data folder before
% running PP as the toolbox will use whatever is in the ppp file, regardless
% of what you type into the starting box.

adcpScreeningThresholds(sden,1)
return
%% Now re-do with ensemble averaging; apply pp tools in this order:
% adcpBinMappingPP
% adcpWorkhorseCorrMagPP - RDI recommended threshold = 64
% adcpWorkhorseEchoRangePP - RDI recommended threshold = 50
% adcpWorkhorseVelocityBeam2EnuPP
% magneticDeclinationPP
% adcpWorkhorseRDIensembleAveragingPP - adjust the averaging interval,
%           default = 60 minutes
% depthPP

% preprocess data
 [ppData, cancel] = preprocessManager(nonUTCRawData, 'qc', mode, false); 
%  [nnData, cancel] = preprocessManager(nonUTCRawData, 'qc', mode, false); 

%%
% now look at ensemble-averaged data for appropriate autoQC thresholds to
% be applied in the autoQCManager step.
%error velocity histograms etc
%cmag already screened. Only apply if not done in single ping screening
%above, combined with surface test

% adcpEnsemblesThresholds(ppData,inst_index,ervthreshold,hvel,vvel,tilt,echo amp,cmagthreshold)
adcpEnsemblesThresholds(ppData,2,0.5,1.5,0.1,40,[],80)

return
%% Run autoQC tests, apply selected thresholds to see impact:
% do one at a time so that the results plot shows the fails for each
% individual test.
% run QC routines over raw data
aqc = autoQCManager(ppData);

% otherwise return new QC data
autoQCData = aqc;

% now review the results of the flags applied with each test
% comment out as required
% adcpThresholdsResults(autoQCData,'surfacetest')
% adcpThresholdsResults(autoQCData,'vvel')
% adcpThresholdsResults(autoQCData,'echorange')
adcpThresholdsResults(autoQCData,'erv')
% adcpThresholdsResults(autoQCData,'cmag')
% adcpThresholdsResults(autoQCData,'echo')
return
%% now we have the thresholds, run the toolbox as is, with the values determined.
% need to delete the pqc file for the RDIs before doing the imos toobox as
% I think that the values in pqc are overwriting edits in the
% configuration. need to check. YES, BUG/

%Next step, export to single ping netcdf and then re-import to matlab, bin
%average and stack.

