function sample_data = depthPP( sample_data, qcLevel, auto )
%DEPTHPP Adds a depth variable to the given data sets, if they contain a
% pressure variable or if there are neighbouring pressure sensor on their same mooring.
%
% This function uses the Gibbs-SeaWater toolbox (TEOS-10) to derive depth data
% from pressure. It adds the depth data as a new variable in the data sets.
% Data sets which do not contain a pressure variable are left unmodified 
% when loaded alone. Data sets which do not contain a pressure variable
% loaded along with data sets which contain a pressure variable on the same
% mooring, will have a depth variable calculated from the other pressure 
% information knowing distances between each others.
%
% This function uses the latitude from metadata. Without any latitude information,
% 1 dbar ~= 1 m.
%
% Inputs:
%   sample_data - cell array of data sets, ideally with pressure variables.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - the same data sets, with depth variables added.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the AODN/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return;                                    end

% auto logical in input to enable running under batch processing
if nargin<3, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

depthVarType = 'variables';
isProfile = false;
switch mode
    case 'profile'
        depthVarType = 'dimensions';
        isProfile = true;
        
end

% check wether height or target depth information is documented
isSensorHeight = false;
isSensorTargetDepth = false;
isSiteTargetDepth = false;

if isfield(sample_data{1}, 'instrument_nominal_height')
    if ~isempty(sample_data{1}.instrument_nominal_height)
        isSensorHeight = true;
    end
end

if isfield(sample_data{1}, 'instrument_nominal_depth')
    if ~isempty(sample_data{1}.instrument_nominal_depth)
        isSensorTargetDepth = true;
    end
end

if isfield(sample_data{1}, 'site_nominal_depth')
    if ~isempty(sample_data{1}.site_nominal_depth)
        isSiteTargetDepth = true;
    end
end

if isfield(sample_data{1}, 'site_depth_at_deployment')
    if ~isempty(sample_data{1}.site_depth_at_deployment)
        isSiteTargetDepth = true;
    end
end

% read options from parameter file
depthFile       = ['Preprocessing' filesep 'depthPP.txt'];
same_family     = readProperty('same_family', depthFile, ',');
include         = readProperty('include', depthFile, ',');
exclude         = readProperty('exclude', depthFile, ',');

if strcmpi(same_family, 'yes')
    same_family = true;
else
    same_family = false;
end

if ~isempty(include)
    include = textscan(include, '%s');
    include = include{1};
end
if ~isempty(exclude)
    exclude = textscan(exclude, '%s');
    exclude = exclude{1};
end

%% loop on every data sets and find out default choices
nDatasets = length(sample_data);

depthIdx   = zeros(nDatasets, 1);
presIdx    = zeros(nDatasets, 1);
presRelIdx = zeros(nDatasets, 1);

useItsOwnDepth   = false(nDatasets, 1);
useItsOwnPresRel = false(nDatasets, 1);
useItsOwnPres    = false(nDatasets, 1);

nearestInsts      = cell(nDatasets, 1);
firstNearestInst  = zeros(nDatasets, 1);
secondNearestInst = zeros(nDatasets, 1);

currentPProutine = mfilename;

for iCurSam = 1:nDatasets
    % read dataset specific PP parameters if exist and override previous entries from
    % parameter file depth.txt
    same_family = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'same_family', same_family); % although we store / define these for each dataset, they are usually the same for a whole mooring
    include     = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'include',     include);
    exclude     = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'exclude',     exclude);
    
    % look for already existing DEPTH, PRES or PRES_REL variables
    depthIdx(iCurSam) = getVar(sample_data{iCurSam}.(depthVarType), 'DEPTH');
    if depthIdx(iCurSam)
        useItsOwnDepth(iCurSam) = true;
    end
    
    presIdx(iCurSam) = getVar(sample_data{iCurSam}.variables, 'PRES');
    if presIdx(iCurSam)
        useItsOwnPres(iCurSam) = true;
    end
    
    presRelIdx(iCurSam) = getVar(sample_data{iCurSam}.variables, 'PRES_REL');
    if presRelIdx(iCurSam)
        useItsOwnPresRel(iCurSam) = true;
    end
    
    % read dataset specific PP parameters if exist and override previous default entries
    useItsOwnDepth(iCurSam)   = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnDepth',   useItsOwnDepth(iCurSam));
    useItsOwnPres(iCurSam)    = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPres',    useItsOwnPres(iCurSam));
    useItsOwnPresRel(iCurSam) = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPresRel', useItsOwnPresRel(iCurSam));
    
    % look for nearest instruments with depth or pressure information
    if ~isProfile && (isSensorHeight || isSensorTargetDepth) && isSiteTargetDepth
        % let's see if part of a mooring with pressure data from other
        % sensors
        for iOtherSam = 1:nDatasets
            % loop on every data sets to find other compatible ones
            presCurIdx      = getVar(sample_data{iOtherSam}.variables, 'PRES');
            presRelCurIdx   = getVar(sample_data{iOtherSam}.variables, 'PRES_REL');
            
            % samples without pressure information are excluded
            if (presCurIdx == 0 && presRelCurIdx == 0), continue; end
            
            if isSensorTargetDepth
                samSensorZ = sample_data{iOtherSam}.instrument_nominal_depth;
            else
                samSensorZ = sample_data{iOtherSam}.instrument_nominal_height;
            end
            
            % current sample or samples without vertical nominal
            % information are excluded
            if iOtherSam == iCurSam || isempty(samSensorZ), continue; end
            
            % we look at the instrument family/ brand of the sample
            samSource = textscan(sample_data{iOtherSam}.instrument, '%s');
            samSource = samSource{1};
            p = 0;
            if same_family
                % only samples that are from the same instrument
                % family/brand of the current sample are selected
                for n = 1:length(samSource)
                    % loop on every words composing the 'instrument' global
                    % attribute of other sample
                    if ~isempty(strfind(sample_data{iCurSam}.instrument, samSource{n}))
                        p = 1;
                    end
                end
            else
                p = 1;
            end
            
            % we look at the including option
            for n = 1:length(include)
                % loop on every words that would include other data set
                if ~isempty(strfind(sample_data{iOtherSam}.instrument, include{n}))
                    p = 1;
                end
            end
            
            % we look at the excluding option
            for n = 1:length(exclude)
                % loop on every words that would exclude other data set
                if ~isempty(strfind(sample_data{iOtherSam}.instrument, exclude{n}))
                    p = 0;
                end
            end
            
            if p > 0
                nearestInsts{iCurSam}(end+1) = iOtherSam;
            end
        end
        
        if isempty(nearestInsts{iCurSam})
            % there is no neighbouring pressure sensor on this mooring from
            % which an actual depth can be computed
            continue;
        else
            nOtherSam = length(nearestInsts{iCurSam});
            % find the nearests pressure data
            diffWithOthers = nan(nOtherSam, 1);
            iFirst  = 0;
            iSecond = 0;
            for iOtherSam = 1:nOtherSam
                if isSensorTargetDepth
                    diffWithOthers(iOtherSam) = sample_data{iCurSam}.instrument_nominal_depth - sample_data{nearestInsts{iCurSam}(iOtherSam)}.instrument_nominal_depth;
                else
                    % below is reversed so that sign convention is the
                    % same
                    diffWithOthers(iOtherSam) = sample_data{nearestInsts{iCurSam}(iOtherSam)}.instrument_nominal_height - sample_data{iCurSam}.instrument_nominal_height;
                end
            end
            
            iAbove = diffWithOthers(diffWithOthers >= 0);
            iBelow = diffWithOthers(diffWithOthers < 0);
            
            if ~isempty(iAbove)
                iAbove = find(diffWithOthers == min(iAbove), 1);
            end
            
            if ~isempty(iBelow)
                iBelow = find(diffWithOthers == max(iBelow), 1);
            end
            
            if isempty(iAbove) && ~isempty(iBelow)
                iFirst = iBelow;
                
                % let's find the second nearest below
                newDiffWithOthers = diffWithOthers;
                newDiffWithOthers(iFirst) = NaN;
                distance = 0;
                
                % if those two sensors are too close to each other then
                % the calculated depth could be too far off the truth
                distMin = 10;
                while distance < distMin && ~all(isnan(newDiffWithOthers))
                    iNextBelow = diffWithOthers == max(newDiffWithOthers(newDiffWithOthers < 0));
                    iNextBelow(isnan(newDiffWithOthers)) = 0; % deals with the case of same depth instrument previously found
                    iNextBelow = find(iNextBelow, 1, 'first');
                    distance = abs(diffWithOthers(iNextBelow) - diffWithOthers(iBelow));
                    if distance >= distMin
                        iSecond = iNextBelow;
                        break;
                    end
                    newDiffWithOthers(iNextBelow) = NaN;
                end
            elseif isempty(iBelow) && ~isempty(iAbove)
                iFirst = iAbove;
                
                % extending reseach to further nearest above didn't
                % lead to better results
                
                %                     % let's find the second nearest above
                %                     newDiffWithOthers = diffWithOthers;
                %                     newDiffWithOthers(iFirst) = NaN;
                %                     distance = 0;
                %
                %                     % if those two sensors are too close to each other then
                %                     % the calculated depth could be too far off the truth
                %                     distMin = 10;
                %                     while distance < distMin && ~all(isnan(newDiffWithOthers))
                %                         iNextAbove = find(diffWithOthers == min(newDiffWithOthers(newDiffWithOthers > 0)), 1);
                %                         distance = abs(diffWithOthers(iNextAbove) - diffWithOthers(iAbove));
                %                         if distance >= distMin
                %                             iSecond = iNextAbove;
                %                             break;
                %                         end
                %                         newDiffWithOthers(iNextAbove) = NaN;
                %                     end
            else
                iFirst  = iAbove;
                iSecond = iBelow;
            end
            
            firstNearestInst(iCurSam)  = iFirst;
            secondNearestInst(iCurSam) = iSecond;
            
            % read dataset specific PP parameters if exist and override previous default entries
            firstNearestInst(iCurSam)  = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'firstNearestInst',  firstNearestInst(iCurSam));
            secondNearestInst(iCurSam) = readDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'secondNearestInst', secondNearestInst(iCurSam));
        end
    else
        if ~isProfile
            fprintf('%s\n', ['Warning : ' sample_data{iCurSam}.toolbox_input_file ...
                ' please document site_nominal_depth or site_depth_at_deployment and either instrument_nominal_height or instrument_nominal_depth '...
                'global attributes so that an actual depth can be '...
                'computed from 1 or 2 other pressure sensors in the mooring']);
        end
        continue;
    end
end

%% create GUI to show default settings
% create descriptions, get methodology and nearest P sensors for each data set
descSam       = cell(nDatasets, 1);
descOtherSam  = cell(nDatasets, 1);
methodsString = {'from DEPTH measurements', ...
    'from PRES measurements', ...
    'from PRES_REL measurements', ...
    'from nearest pressure sensors'};
methodsSamString  = cell(nDatasets, 1); % cell array of strings of possible methods per dataset
iMethodsSamString = false(nDatasets, 4); % logical array with methodsString of possible methods per dataset
iMethodSam        = zeros(nDatasets, 1); % index of selected method within methodsSamString per dataset

for iCurSam = 1:nDatasets
    descSam{iCurSam} = genSampleDataDesc(sample_data{iCurSam}, 'medium');
    
    iMethodsSamString(iCurSam, 4) = true;
    if useItsOwnPresRel(iCurSam)
        iMethodsSamString(iCurSam, 3) = true;
    end
    if useItsOwnPres(iCurSam)
        iMethodsSamString(iCurSam, 2) = true;
    end
    if useItsOwnDepth(iCurSam)
        iMethodsSamString(iCurSam, 1) = true;
    end
    
    % given the order of definition, the first methodology is the default one
    iMethodSam(iCurSam) = 1;
    
    descOtherSam{iCurSam}{1} = ' - ';
    nOtherSam = length(nearestInsts{iCurSam});
    for iOtherSam = 1:nOtherSam
        descOtherSam{iCurSam}{iOtherSam+1} = genSampleDataDesc(sample_data{nearestInsts{iCurSam}(iOtherSam)}, 'short');
    end
end

if ~auto && ~isProfile
    f = figure(...
        'Name',        'Depth Computation',...
        'Visible',     'off',...
        'MenuBar'  ,   'none',...
        'Resize',      'off',...
        'WindowStyle', 'Modal',...
        'NumberTitle', 'off');
    
    cancelButton       = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
    resetParamsButton  = uicontrol('Style', 'pushbutton', 'String', 'Reset to default mapping (delete last saved)');
    resetMappingButton = uicontrol('Style', 'pushbutton', 'String', 'Reset to last performed mapping (saved) if any');
    confirmButton      = uicontrol('Style', 'pushbutton', 'String', 'Ok');
    
    descSamUic           = nan(nDatasets, 1);
    methodSamUic         = nan(nDatasets, 1);
    firstNearestInstUic  = nan(nDatasets, 1);
    andStrUic            = nan(nDatasets, 1);
    secondNearestInstUic = nan(nDatasets, 1);
    for iCurSam = 1:nDatasets
        descSamUic(iCurSam) = uicontrol( ...
            'Style',               'text', ...
            'HorizontalAlignment', 'left', ...
            'String',              descSam{iCurSam});
        
        methodsSamString{iCurSam} = methodsString(iMethodsSamString(iCurSam, :));
        methodSamUic(iCurSam) = uicontrol( ...
            'Style',    'popupmenu', ...
            'String',   methodsSamString{iCurSam}, ...
            'Value',    iMethodSam(iCurSam), ...
            'Callback', {@methodSamCallback, iCurSam});
        
        switch methodsSamString{iCurSam}{iMethodSam(iCurSam)}
            case methodsString{end}
                nearestInstVisibility = 'on';
                
            otherwise
                nearestInstVisibility = 'off';
        end
        
        firstNearestInstUic(iCurSam) = uicontrol( ...
            'Style',   'popupmenu', ...
            'String',  descOtherSam{iCurSam}, ...
            'Value',   firstNearestInst(iCurSam) + 1, ...
            'Visible', nearestInstVisibility);
        
        andStrUic(iCurSam) = uicontrol( ...
            'Style',  'text', ...
            'String', 'and', ...
            'Visible', nearestInstVisibility);
        
        secondNearestInstUic(iCurSam) = uicontrol( ...
            'Style',   'popupmenu', ...
            'String',  descOtherSam{iCurSam}, ...
            'Value',   secondNearestInst(iCurSam) + 1, ...
            'Visible', nearestInstVisibility);
    end
    
    paramsString = 'Look within same kind of instruments: ';
    if same_family
        paramsString = [paramsString, 'Yes.'];
    else
        paramsString = [paramsString, 'No.'];
    end
    
    if ~isempty(include)
        includeStr = [include,[repmat({' '},numel(include)-1,1);{[]}]]';
        includeStr = [includeStr{:}];
        paramsString = [paramsString, ' Include: ' includeStr '.'];
    end
    
    if ~isempty(exclude)
        excludeStr = [exclude,[repmat({' '},numel(exclude)-1,1);{[]}]]';
        excludeStr = [excludeStr{:}];
        paramsString = [paramsString, ' Exclude: ' excludeStr '.'];
    end
    paramsStringUic = uicontrol('Style', 'text', 'String', paramsString);
    
    % set all widgets to normalized for positioning
    set(f,                    'Units', 'normalized');
    set(cancelButton,         'Units', 'normalized');
    set(resetParamsButton,    'Units', 'normalized');
    set(resetMappingButton,   'Units', 'normalized');
    set(confirmButton,        'Units', 'normalized');
    set(descSamUic,           'Units', 'normalized');
    set(methodSamUic,         'Units', 'normalized');
    set(firstNearestInstUic,  'Units', 'normalized');
    set(andStrUic,            'Units', 'normalized');
    set(secondNearestInstUic, 'Units', 'normalized');
    set(paramsStringUic,      'Units', 'normalized');
    
    set(f,             'Position', [0.2 0.35 0.6 0.0222 * (nDatasets + 2 )]); % need to include 2 extra space for the depth.txt parameters and the row of buttons
    
    rowHeight = 1 / (nDatasets + 2);
    
    set(cancelButton,       'Position', [0.0  0.0  0.25 rowHeight]);
    set(resetParamsButton,  'Position', [0.25 0.0  0.25 rowHeight]);
    set(resetMappingButton, 'Position', [0.5  0.0  0.25 rowHeight]);
    set(confirmButton,      'Position', [0.75 0.0  0.25 rowHeight]);
    
    for k = 1:nDatasets
        rowStart = 1.0 - (k + 1) * rowHeight;
        
        set(descSamUic (k),          'Position', [0.0   rowStart 0.4   rowHeight]);
        set(methodSamUic(k),         'Position', [0.4   rowStart 0.2   rowHeight]);
        set(firstNearestInstUic(k),  'Position', [0.6   rowStart 0.175 rowHeight]);
        set(andStrUic(k),            'Position', [0.775 rowStart 0.05  rowHeight]);
        set(secondNearestInstUic(k), 'Position', [0.825 rowStart 0.175 rowHeight]);
    end
    
    set(paramsStringUic, 'Position', [0.0 (1.0 - rowHeight) 1 rowHeight]);
    
    % set widget callbacks
    set(f,             'CloseRequestFcn',   @cancelCallback);
    set(f,             'WindowKeyPressFcn', @keyPressCallback);
    
    set(cancelButton,       'Callback',     @cancelCallback);
    set(resetParamsButton,  'Callback',     @resetParamsCallback);
    set(resetMappingButton, 'Callback',     @resetMappingCallback);
    set(confirmButton,      'Callback',     @confirmCallback);
    
    cancel = false;
    reset  = false;
    
    set(f, 'Visible', 'on');
    
    uiwait(f);
    
    if cancel
        return;
    end
    
    if reset
        sample_data = depthPP(sample_data, qcLevel, auto);
        return;
    end
end

%% loop on every data sets again and apply choices
for iCurSam = 1:nDatasets
    % if data set already contains depth data then next sample data
    if useItsOwnDepth(iCurSam), continue; end
    
    if useItsOwnPres(iCurSam) || useItsOwnPresRel(iCurSam)
        % we can compute DEPTH straight from the instrument pressure
        % measurements
        if presRelIdx(iCurSam)
            % update from a relative measured pressure
            relPres = sample_data{iCurSam}.variables{presRelIdx(iCurSam)}.data;
            presComment = ['relative ' ...
                'pressure measurements (calibration offset ' ...
                'usually performed to balance current ' ...
                'atmospheric pressure and acute sensor ' ...
                'precision at a deployed depth)'];
            dimensions  = sample_data{iCurSam}.variables{presRelIdx(iCurSam)}.dimensions;
            coordinates = sample_data{iCurSam}.variables{presRelIdx(iCurSam)}.coordinates;
        else
            % update from an absolute measured pressure, substracting a 
            % constant value 10.1325 dbar for nominal atmospheric pressure
            % like SeaBird does in its processed files
            relPres = sample_data{iCurSam}.variables{presIdx(iCurSam)}.data - gsw_P0/10^4;
            presComment = ['absolute ' ...
                'pressure measurements to which a nominal ' ...
                'value for atmospheric pressure (10.1325 dbar) ' ...
                'has been substracted'];
            dimensions  = sample_data{iCurSam}.variables{presIdx(iCurSam)}.dimensions;
            coordinates = sample_data{iCurSam}.variables{presIdx(iCurSam)}.coordinates;
        end
        
        if ~isempty(sample_data{iCurSam}.geospatial_lat_min) && ~isempty(sample_data{iCurSam}.geospatial_lat_max)
            % compute depth with Gibbs-SeaWater toolbox
            if sample_data{iCurSam}.geospatial_lat_min == sample_data{iCurSam}.geospatial_lat_max
                % latitude doesn't change in the dataset
                computedDepth = - gsw_z_from_p(relPres, sample_data{iCurSam}.geospatial_lat_min);
                clear relPres;
                computedDepthComment = ['depthPP: Depth computed using the ' ...
                    'Gibbs-SeaWater toolbox (TEOS-10) v3.06 from latitude and ' ...
                    presComment '.'];
            else
                % latitude does change in the dataset, so we use the mean
                % latitude with Gibbs-Seawater toolbox
                meanLat = sample_data{iCurSam}.geospatial_lat_min + ...
                    (sample_data{iCurSam}.geospatial_lat_max - sample_data{iCurSam}.geospatial_lat_min)/2;
                
                computedDepth = - gsw_z_from_p(relPres, meanLat);
                clear relPres;
                computedDepthComment = ['depthPP: Depth computed using the ' ...
                    'Gibbs-SeaWater toolbox (TEOS-10) v3.06 from mean latitude and ' ...
                    presComment '.'];
            end
        else
            % without latitude information, we assume 1dbar ~= 1m
            computedDepth = relPres;
            clear relPres;
            computedDepthComment = ['depthPP: Depth computed from ' ...
                presComment ', assuming 1dbar ~= 1m.'];
        end
    else
        % if no pressure data, try to compute it from other sensors in the
        % mooring, otherwise go to next sample data
        if (isSensorHeight || isSensorTargetDepth) && isSiteTargetDepth
            if isempty(nearestInsts{iCurSam})
                fprintf('%s\n', ['Warning : ' descSam{iCurSam} ...
                    ' has no neighbouring pressure sensor on this mooring from ' ...
                    'which an actual depth can be inferred']);
                continue;
            else
                iFirst  = firstNearestInst(iCurSam);
                iSecond = secondNearestInst(iCurSam);
                
                if iSecond == 0 && iFirst ~= 0
                    tidalAmplitudeComment = ' Tidal amplitude is not accurate.';
                    fprintf('%s\n', ['Warning : ' descSam{iCurSam} ...
                        ' has its actual depth inferred from only one neighbouring pressure sensor ' ...
                        'on mooring.' tidalAmplitudeComment]);
                    % we found only one sensor
                    presIdxOther    = getVar(sample_data{nearestInsts{iCurSam}(iFirst)}.variables, 'PRES');
                    presRelIdxOther = getVar(sample_data{nearestInsts{iCurSam}(iFirst)}.variables, 'PRES_REL');
                    
                    if presRelIdxOther == 0
                        % update from an absolute pressure like SeaBird computes
                        % a relative pressure in its processed files, substracting a constant value
                        % 10.1325 dbar for nominal atmospheric pressure
                        relPresOther = sample_data{nearestInsts{iCurSam}(iFirst)}.variables{presIdxOther}.data - gsw_P0/10^4;
                        presComment = ['absolute ' ...
                            'pressure measurements to which a nominal ' ...
                            'value for atmospheric pressure (10.1325 dbar) ' ...
                            'has been substracted'];
                    else
                        % update from a relative pressure measurement
                        relPresOther = sample_data{nearestInsts{iCurSam}(iFirst)}.variables{presRelIdxOther}.data;
                        presComment = ['relative ' ...
                            'pressure measurements (calibration offset ' ...
                            'usually performed to balance current ' ...
                            'atmospheric pressure and acute sensor ' ...
                            'precision at a deployed depth)'];
                    end
                    
                    % compute pressure at current sensor using trigonometry and
                    % assuming sensors repartition on a line between the 
                    % nearest pressure sensor and the mooring's anchor
                    %
                    % the only drawback is that tidal amplitude is 
                    % flattenned by static value of siteDepth
                    if isfield(sample_data{iCurSam}, 'site_nominal_depth')
                        if ~isempty(sample_data{iCurSam}.site_nominal_depth)
                            siteDepth = sample_data{iCurSam}.site_nominal_depth;
                        end
                    end
                    
                    if isfield(sample_data{iCurSam}, 'site_depth_at_deployment')
                        if ~isempty(sample_data{iCurSam}.site_depth_at_deployment)
                            siteDepth = sample_data{iCurSam}.site_depth_at_deployment;
                        end
                    end
                    
                    if isSensorTargetDepth
                        nominalHeightOther      = siteDepth - sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_depth;
                        nominalHeightCurSensor  = siteDepth - sample_data{iCurSam}.instrument_nominal_depth;
                    else
                        nominalHeightOther      = sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_height;
                        nominalHeightCurSensor  = sample_data{iCurSam}.instrument_nominal_height;
                    end
                    
                    % theta is the angle between the vertical and line
                    % formed by the sensors
                    %
                    % cos(theta) = heightOther/nominalHeightOther
                    % and
                    % cos(theta) = heightCurSensor/nominalHeightCurSensor
                    %
                    % computedDepth = nominalSiteDepth - nominalHeightCurSensor * (nominalSiteDepth - zOther) / nominalHeightOther
                    %
                    % pressure = density*gravity*depth
                    %
                    if ~isempty(sample_data{iCurSam}.geospatial_lat_min) && ~isempty(sample_data{iCurSam}.geospatial_lat_max)
                        % compute depth with Gibbs-SeaWater toolbox
                        % depth ~= - gsw_z_from_p(relative_pressure, latitude)
                        if sample_data{iCurSam}.geospatial_lat_min == sample_data{iCurSam}.geospatial_lat_max
                            zOther = - gsw_z_from_p(relPresOther, sample_data{iCurSam}.geospatial_lat_min);
                            computedDepthComment  = ['depthPP: Depth inferred from only one neighbouring pressure sensor ' ...
                                descOtherSam{iCurSam}{iFirst + 1} ', using the Gibbs-SeaWater toolbox ' ...
                                '(TEOS-10) v3.06 from latitude and ' presComment '.' tidalAmplitudeComment];
                        else
                            meanLat = sample_data{iCurSam}.geospatial_lat_min + ...
                                (sample_data{iCurSam}.geospatial_lat_max - sample_data{iCurSam}.geospatial_lat_min)/2;
                            zOther = - gsw_z_from_p(relPresOther, meanLat);
                            computedDepthComment  = ['depthPP: Depth inferred from only one neighbouring pressure sensor ' ...
                                descOtherSam{iCurSam}{iFirst + 1} ', using the Gibbs-SeaWater toolbox ' ...
                                '(TEOS-10) v3.06 from mean latitude and ' presComment '.' tidalAmplitudeComment];
                        end
                    else
                        % without latitude information, we assume 1dbar ~= 1m
                        zOther = relPresOther;
                        computedDepthComment  = ['depthPP: Depth inferred from only one neighbouring pressure sensor ' ...
                            descOtherSam{iCurSam}{iFirst + 1} ' with ' presComment ', assuming 1dbar ~= 1m.' tidalAmplitudeComment];
                    end
                    clear relPresOther;
                    
                    tOther = sample_data{nearestInsts{iCurSam}(iFirst)}.dimensions{getVar(sample_data{nearestInsts{iCurSam}(iFirst)}.dimensions, 'TIME')}.data;
                    tCur   = sample_data{iCurSam}.dimensions{getVar(sample_data{iCurSam}.dimensions, 'TIME')}.data;
                    
                    % let's interpolate the other data set depth values in time
                    % to fit with the current data set time values
                    zOther = interp1(tOther, zOther, tCur);
                    clear tOther tCur;
                    
                    computedDepth = siteDepth - nominalHeightCurSensor * (siteDepth - zOther) / nominalHeightOther;
                    clear zOther;
                elseif iSecond ~= 0 && iFirst ~= 0
                    presIdxFirst     = getVar(sample_data{nearestInsts{iCurSam}(iFirst)}.variables, 'PRES');
                    presRelIdxFirst  = getVar(sample_data{nearestInsts{iCurSam}(iFirst)}.variables, 'PRES_REL');
                    
                    presIdxSecond    = getVar(sample_data{nearestInsts{iCurSam}(iSecond)}.variables, 'PRES');
                    presRelIdxSecond = getVar(sample_data{nearestInsts{iCurSam}(iSecond)}.variables, 'PRES_REL');
                    
                    if presIdxFirst ~= 0 && presIdxSecond ~= 0
                        % update from an absolute pressure like SeaBird computes
                        % a relative pressure in its processed files, substracting a constant value
                        % 10.1325 dbar for nominal atmospheric pressure
                        relPresFirst  = sample_data{nearestInsts{iCurSam}(iFirst )}.variables{presIdxFirst }.data - gsw_P0/10^4;
                        relPresSecond = sample_data{nearestInsts{iCurSam}(iSecond)}.variables{presIdxSecond}.data - gsw_P0/10^4;
                        presComment   = ['absolute ' ...
                            'pressure measurements to which a nominal ' ...
                            'value for atmospheric pressure (10.1325 dbar) ' ...
                            'has been substracted'];
                    elseif presIdxFirst ~= 0 && presIdxSecond == 0
                        relPresFirst  = sample_data{nearestInsts{iCurSam}(iFirst )}.variables{presIdxFirst    }.data - gsw_P0/10^4;
                        relPresSecond = sample_data{nearestInsts{iCurSam}(iSecond)}.variables{presRelIdxSecond}.data;
                        presComment   = ['relative and absolute ' ...
                            'pressure measurements to which a nominal ' ...
                            'value for atmospheric pressure (10.1325 dbar) ' ...
                            'has been substracted'];
                    elseif presIdxFirst == 0 && presIdxSecond ~= 0
                        relPresFirst  = sample_data{nearestInsts{iCurSam}(iFirst )}.variables{presRelIdxFirst}.data;
                        relPresSecond = sample_data{nearestInsts{iCurSam}(iSecond)}.variables{presIdxSecond  }.data - gsw_P0/10^4;
                        presComment   = ['relative and absolute ' ...
                            'pressure measurements to which a nominal ' ...
                            'value for atmospheric pressure (10.1325 dbar) ' ...
                            'has been substracted'];
                    else
                        % update from a relative measured pressure
                        relPresFirst  = sample_data{nearestInsts{iCurSam}(iFirst )}.variables{presRelIdxFirst }.data;
                        relPresSecond = sample_data{nearestInsts{iCurSam}(iSecond)}.variables{presRelIdxSecond}.data;
                        presComment   = ['relative ' ...
                            'pressure measurements (calibration offset ' ...
                            'usually performed to balance current ' ...
                            'atmospheric pressure and acute sensor ' ...
                            'precision at a deployed depth)'];
                    end
                    
                    % compute pressure at current sensor using trigonometry and
                    % assuming sensors repartition on a line between the two
                    % nearest pressure sensors
                    if isSensorTargetDepth
                        distFirstSecond    = sample_data{nearestInsts{iCurSam}(iSecond)}.instrument_nominal_depth - sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_depth;
                        distFirstCurSensor = sample_data{iCurSam}.instrument_nominal_depth - sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_depth;
                    else
                        distFirstSecond    = sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_height - sample_data{nearestInsts{iCurSam}(iSecond)}.instrument_nominal_height;
                        distFirstCurSensor = sample_data{nearestInsts{iCurSam}(iFirst)}.instrument_nominal_height - sample_data{iCurSam}.instrument_nominal_height;
                    end
                    
                    % theta is the angle between the vertical and line
                    % formed by the sensors
                    %
                    % cos(theta) = depthFirstSecond/distFirstSecond
                    % and
                    % cos(theta) = depthFirstCurSensor/distFirstCurSensor
                    %
                    % computedDepth = (distFirstCurSensor/distFirstSecond) ...
                    %        * (zSecond - zFirst) + zFirst
                    %
                    % pressure = density*gravity*depth
                    %
                    if ~isempty(sample_data{iCurSam}.geospatial_lat_min) && ~isempty(sample_data{iCurSam}.geospatial_lat_max)
                        % compute depth with Gibbs-SeaWater toolbox
                        % depth ~= - gsw_z_from_p(relative_pressure, latitude)
                        if sample_data{iCurSam}.geospatial_lat_min == sample_data{iCurSam}.geospatial_lat_max
                            zFirst  = - gsw_z_from_p(relPresFirst,  sample_data{iCurSam}.geospatial_lat_min);
                            zSecond = - gsw_z_from_p(relPresSecond, sample_data{iCurSam}.geospatial_lat_min);
                            
                            computedDepthComment = ['depthPP: Depth inferred from ' ...
                                '2 neighbouring pressure sensors ' descOtherSam{iCurSam}{iFirst + 1} ...
                                ' and ' descOtherSam{iCurSam}{iSecond + 1} ', using the ' ...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.06 from latitude and ' ...
                                presComment '.'];
                        else
                            meanLat = sample_data{iCurSam}.geospatial_lat_min + ...
                                (sample_data{iCurSam}.geospatial_lat_max - sample_data{iCurSam}.geospatial_lat_min)/2;
                            
                            zFirst  = - gsw_z_from_p(relPresFirst,  meanLat);
                            zSecond = - gsw_z_from_p(relPresSecond, meanLat);
                            
                            computedDepthComment = ['depthPP: Depth inferred from ' ...
                                '2 neighbouring pressure sensors ' descOtherSam{iCurSam}{iFirst + 1} ...
                                ' and ' descOtherSam{iCurSam}{iSecond + 1} ', using the ' ...
                                'Gibbs-SeaWater toolbox (TEOS-10) v3.06 from mean latitude and ' ...
                                presComment '.'];
                        end
                    else
                        % without latitude information, we assume 1dbar ~= 1m
                        zFirst  = relPresFirst;
                        zSecond = relPresSecond;
                        
                        computedDepthComment = ['depthPP: Depth inferred from ' ...
                            '2 neighbouring pressure sensors ' descOtherSam{iCurSam}{iFirst + 1} ...
                            ' and ' descOtherSam{iCurSam}{iSecond + 1} ', with ' ...
                            presComment ', assuming 1dbar ~= 1m.'];
                    end
                    clear relPresFirst relPresSecond;
                    
                    tCur    = sample_data{iCurSam}.dimensions{getVar(sample_data{iCurSam}.dimensions, 'TIME')}.data;                    
                    tFirst  = sample_data{nearestInsts{iCurSam}(iFirst )}.dimensions{getVar(sample_data{nearestInsts{iCurSam}(iFirst )}.dimensions, 'TIME')}.data;
                    tSecond = sample_data{nearestInsts{iCurSam}(iSecond)}.dimensions{getVar(sample_data{nearestInsts{iCurSam}(iSecond)}.dimensions, 'TIME')}.data;
                    
                    % let's interpolate data so we have consistent period
                    % sample and time sample over the 3 data sets
                    zFirst  = interp1(tFirst,  zFirst,  tCur);
                    zSecond = interp1(tSecond, zSecond, tCur);
                    clear tFirst tSecond tCur;
                    
                    computedDepth = (distFirstCurSensor/distFirstSecond) ...
                        * (zSecond - zFirst) + zFirst;
                    clear zFirst zSecond;
                else
                    fprintf('%s\n', ['Warning : ' descSam{iCurSam} ...
                        ' will not have its depth inferred from any neighbouring pressure sensor ' ...
                        'on mooring']);
                    
                    % write/update dataset PP parameters before moving to
                    % the next sample_data
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'same_family',       same_family);
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'include',           include);
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'exclude',           exclude);
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnDepth',    useItsOwnDepth(iCurSam));
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPres',     useItsOwnPres(iCurSam));
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPresRel',  useItsOwnPresRel(iCurSam));
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'firstNearestInst',  firstNearestInst(iCurSam));
                    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'secondNearestInst', secondNearestInst(iCurSam));
                    continue;
                end
            end
        else
            fprintf('%s\n', ['Warning : ' sample_data{iCurSam}.toolbox_input_file ...
                ' please document site_nominal_depth or site_depth_at_deployment and either instrument_nominal_height or instrument_nominal_depth ' ...
                'global attributes so that an actual depth can be ' ...
                'computed from 1 or 2 other pressure sensors in the mooring']);
            continue;
        end
        
        % variable DEPTH will be a function of dimension TIME
        dimensions = getVar(sample_data{iCurSam}.dimensions, 'TIME');
        
        % hopefully the last variable in the file is a data variable
        coordinates = sample_data{iCurSam}.variables{end}.coordinates;
    end
    
    if depthIdx(iCurSam)
        % update existing depth data in data set
        sample_data{iCurSam}.(depthVarType).data = computedDepth;
        
        depthComment = sample_data{iCurSam}.(depthVarType).comment;
        if isempty(depthComment)
            sample_data{iCurSam}.(depthVarType).comment = computedDepthComment;
        else
            sample_data{iCurSam}.(depthVarType).comment = [comment ' ' computedDepthComment];
        end
        
    else
        % add depth data as new variable in data set
        sample_data{iCurSam} = addVar( ...
            sample_data{iCurSam}, ...
            'DEPTH', ...
            computedDepth, ...
            dimensions, ...
            computedDepthComment, ...
            coordinates);
    end
    
    % update vertical min/max from newly computed DEPTH variable
    sample_data{iCurSam}.geospatial_vertical_min = min(computedDepth);
    sample_data{iCurSam}.geospatial_vertical_max = max(computedDepth);
    clear computedDepth;
    
    sample_data{iCurSam}.comment = strrep(sample_data{iCurSam}.comment, 'NOMINAL_DEPTH', 'DEPTH min and max');
    
    history = sample_data{iCurSam}.history;
    if isempty(history)
        sample_data{iCurSam}.history = sprintf('%s - %s', ...
            datestr(now_utc, readProperty('exportNetCDF.dateFormat')), ...
            computedDepthComment);
    else
        sample_data{iCurSam}.history = sprintf('%s\n%s - %s', history, ...
            datestr(now_utc, readProperty('exportNetCDF.dateFormat')), ...
            computedDepthComment);
    end
    
    % update the keywords with variable DEPTH
    sample_data{iCurSam}.keywords = [sample_data{iCurSam}.keywords, ', DEPTH'];
    
    if strcmpi(mode, 'profile')
        %let's redefine the coordinates attribute for each variables
        nVars = length(sample_data{iCurSam}.variables);
        for i=1:nVars
            if isfield(sample_data{iCurSam}.variables{i}, 'coordinates')
                sample_data{iCurSam}.variables{i}.coordinates = [sample_data{iCurSam}.variables{i}.coordinates ' DEPTH'];
            end
        end
    end
    
    % write/update dataset PP parameters
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'same_family',       same_family);
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'include',           include);
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'exclude',           exclude);
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnDepth',    useItsOwnDepth(iCurSam));
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPres',     useItsOwnPres(iCurSam));
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'useItsOwnPresRel',  useItsOwnPresRel(iCurSam));
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'firstNearestInst',  firstNearestInst(iCurSam));
    writeDatasetParameter(sample_data{iCurSam}.toolbox_input_file, currentPProutine, 'secondNearestInst', secondNearestInst(iCurSam));
end

%% Callbacks
    function methodSamCallback(source,ev,j)
        %RESETCALLBACK Reset to default choices in the GUI.
        %
        iMethod = get(methodSamUic(j), 'Value');
        switch methodsSamString{j}{iMethod}
            case methodsString{end}
                nearestInstVisibility = 'on';
                
            otherwise
                nearestInstVisibility = 'off';
        end
        
        set([firstNearestInstUic(j), andStrUic(j), secondNearestInstUic(j)], ...
            'Visible', nearestInstVisibility);
    end

    function keyPressCallback(source,ev)
        %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has
        % focus, the dialog is cancelled/confirmed. This is done by delegating
        % to the cancelCallback/confirmCallback functions.
        %
        if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev);
        elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev);
        end
    end

    function cancelCallback(source,ev)
        %CANCELCALLBACK Cancel button callback. Set cancel to true and closes the
        % dialog.
        %
        cancel = true;
        reset  = false;
        delete(f);
    end

    function resetParamsCallback(source,ev)
        %RESETPARAMSCALLBACK Reset dataset specific parameters re-start
        %from depthPP.txt parameters
        %
        fieldsToBeDeleted = {'same_family', 'include', 'exclude', ...
            'useItsOwnDepth', 'useItsOwnPres', 'useItsOwnPresRel', ...
            'firstNearestInst', 'secondNearestInst'};
        for j = 1:nDatasets
            ppp = struct([]);
            pppFile = [sample_data{j}.toolbox_input_file '.ppp'];
            if exist(pppFile, 'file')
                load(pppFile, '-mat', 'ppp')
            end
            if ~isempty(ppp)
                if isfield(ppp, currentPProutine)
                    for l = 1:length(fieldsToBeDeleted)
                        if isfield(ppp.(currentPProutine), fieldsToBeDeleted{l})
                            ppp.(currentPProutine) = rmfield(ppp.(currentPProutine), fieldsToBeDeleted{l});
                        end
                    end
                end
                save(pppFile, 'ppp');
            end
        end
        reset = true;
        delete(f);
    end

    function resetMappingCallback(source,ev)
        %RESETMAPPINGCALLBACK Reset to current default choices in the GUI.
        %
        for j = 1:nDatasets
            set(methodSamUic(j),         'Value', iMethodSam(j));
            methodSamCallback(source,ev,j)
            
            set(firstNearestInstUic(j),  'Value', firstNearestInst(j)  + 1);
            set(secondNearestInstUic(j), 'Value', secondNearestInst(j) + 1);
        end
        reset = false;
    end

    function confirmCallback(source,ev)
        %CONFIRMCALLBACK Set choices as they appear on the GUI and closes the dialog.
        %
        for j = 1:nDatasets
            useItsOwnDepth(j)   = false;
            useItsOwnPres(j)    = false;
            useItsOwnPresRel(j) = false;
            
            strings = get(methodSamUic(j), 'String');
            value   = get(methodSamUic(j), 'Value');
            
            switch strings{value}
                case methodsString{1} % from DEPTH measurements
                    useItsOwnDepth(j)   = true;
                    
                case methodsString{2} % from PRES measurements
                    useItsOwnPres(j)    = true;
                    
                case methodsString{3} % from PRES_REL measurements
                    useItsOwnPresRel(j) = true;
                    
            end
            
            firstNearestInst(j)  = get(firstNearestInstUic(j),  'Value') - 1;
            secondNearestInst(j) = get(secondNearestInstUic(j), 'Value') - 1;
        end
        reset = false;
        delete(f);
    end
end