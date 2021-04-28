function [sample_data, varChecked, paramsLog, df] = imosEchoRangeSetQC( sample_data, auto )
%IMOSECHORANGEQC Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the echo intensity diagnostic variable.
%
% Echo Range test :
% This test checks the difference between the highest and lowest values in the 4 beams
% in each bin (echo intensity range, EIR) at each time stamp. 
% The echo intensity data should ideally be bin-mapped first using
% adcpBinMappingPP.m routine.
% If the difference exceeds a threshold, the entire bin is flagged as bad
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   auto - logical, run QC in batch mode
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%   varChecked  - cell array of variables' name which have been checked
%   paramsLog   - string containing details about params' procedure to include in QC log
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Rebecca Cowley <rebecca.cowley@csiro.au>
%
narginchk(1, 2);
if ~isstruct(sample_data), error('sample_data must be a struct'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

varChecked = {};
paramsLog  = [];

% get all necessary dimensions and variables id in sample_data struct
idUcur = 0;
idVcur = 0;
idWcur = 0;
idCspd = 0;
idCdir = 0;
idABSIC = cell(4, 1);
for j=1:4
    idABSIC{j}  = 0;
end
lenVar = length(sample_data.variables);
for i=1:lenVar
    paramName = sample_data.variables{i}.name;
    
    if strncmpi(paramName, 'UCUR', 4),  idUcur = i; end
    if strncmpi(paramName, 'VCUR', 4),  idVcur = i; end
    if strcmpi(paramName, 'WCUR'),      idWcur = i; end
    if strcmpi(paramName, 'CSPD'),      idCspd = i; end
    if strncmpi(paramName, 'CDIR', 4),  idCdir = i; end
    for j=1:4
        cc = int2str(j);
        if strcmpi(paramName, ['ABSIC' cc]), idABSIC{j} = i; end
    end
end

% check if the data is compatible with the QC algorithm
idMandatory = (idUcur | idVcur | idWcur | idCspd | idCdir);
for j=1:4
    idMandatory = idMandatory & idABSIC{j};
end
if ~idMandatory, return; end

% let's get the associated vertical dimension
idVertDim = sample_data.variables{idABSIC{1}}.dimensions(2);
if strcmpi(sample_data.dimensions{idVertDim}.name, 'DIST_ALONG_BEAMS')
    disp(['Warning : imosEchoRangeSetQC applied with a non tilt-corrected ABSICn (no bin mapping) on dataset ' sample_data.toolbox_input_file]);
end

qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

%Pull out echo intensity
sizeData = size(sample_data.variables{idABSIC{1}}.data);
ea = nan(4, sizeData(1), sizeData(2));
for j=1:4
    ea(j, :, :) = sample_data.variables{idABSIC{j}}.data;
end

% read in filter parameters
propFile  = fullfile('AutomaticQC', 'imosEchoRangeSetQC.txt');
ea_fishthresh = str2double(readProperty('ea_fishthresh',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;
ea_fishthresh = readDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_fishthresh', ea_fishthresh);

paramsLog = ['ea_fishthresh=' num2str(ea_fishthresh)];

%TODO: refactor from below
% Run QC
% Following code is adapted from the UWA 'adcpfishdetection.m' code

[n, t, m]=size(ea); % m depth cells, n (4) beams, t timesteps
% same flags are given to any variable
bad_ea = ones(n,t,m,'int8')*rawFlag;

% matrix operation of the UW original code which loops over each timestep
[B, Ix]=sort(ea,1); %sort echo from highest to lowest along each bin
    %step one - really only useful for data in beam coordinates. If one
    %beam fails, then can do 3-beam solutions

try
    frame_of_reference = sample_data.meta.adcp_info.coords.frame_of_reference;
    is_enu = strcmpi(frame_of_reference,'enu');
catch
    try
        is_enu = unique(sample_data.meta.fixedLeader.coordinateTransform) ~=7;
    catch
        is_enu = false;
    end
end
if is_enu
    df = B(4,:,:)-B(1,:,:); %get the difference from highest value to lowest
    ind=df>ea_fishthresh; % problematic depth cells
    bad_ea(ind) = true; %flag these as bad (individual cells)
end
%step 2: useful for data in both beam and ENU coordinates. Flags entire
%bin of velocity data
df = B(4,:,:)-B(2,:,:); %get the difference from highest value to second lowest
ind=df>ea_fishthresh; % problematic depth cells
bad_ea(:,ind) = true; %flag the entire bin (all beams) as bad


%have flags for entire bins for each beam. Can use values for beam 1 to get single flag
%per timestamp/depth bin:
flags = squeeze(bad_ea(1,:,:));

% Run QC filter (iFail) on velocity data

flags(flags == 1) = badFlag;
flags(flags == 0) = goodFlag;

sample_data.variables{idUcur}.flags = flags;
sample_data.variables{idVcur}.flags = flags;
sample_data.variables{idWcur}.flags = flags;

varChecked = {sample_data.variables{idUcur}.name, ...
    sample_data.variables{idVcur}.name, ...
    sample_data.variables{idWcur}.name};

if idCdir
    sample_data.variables{idCdir}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCdir}.name}];
end

if idCspd
    sample_data.variables{idCspd}.flags = flags;
    varChecked = [varChecked, {sample_data.variables{idCspd}.name}];
end

% write/update dataset QC parameters
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ea_fishthresh', ea_fishthresh);

end
