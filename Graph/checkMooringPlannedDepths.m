function checkMooringPlannedDepths(sample_data, isQC, saveToFile, exportDir)
%CHECKMOORINGPLANNEDDEPTHS Opens a new window where the DEPTH
% variable of all intruments is plotted and compared to the
% planned depth.
%
% Inputs:
%   sample_data - cell array of structs containing the entire data set and dimension data.
%
%   varName     - string containing the IMOS code for requested parameter.
%
%   isQC        - logical to plot only good data or not.
%
%   saveToFile  - logical to save the plot on disk or not.
%
%   exportDir   - string containing the destination folder to where the
%               plot is saved on disk.
%
% Author: Rebecca Cowley <rebecca.cowley@csiro.au>
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
narginchk(4,4);

if ~iscell(sample_data),    error('sample_data must be a cell array');  end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

varTitle = imosParameters('DEPTH', 'long_name');
varUnit = imosParameters('DEPTH', 'uom');

stringQC = 'all';
if isQC, stringQC = 'only good and non QC''d'; end

title = [sample_data{1}.deployment_code ' mooring planned vs measured ' stringQC ' ' varTitle];

% retrieve good flag values
qcSet     = str2double(readProperty('toolbox.qc_set'));
rawFlag   = imosQCFlag('raw', qcSet, 'flag');
goodFlag  = imosQCFlag('good', qcSet, 'flag');
pGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
goodFlags = [rawFlag, goodFlag, pGoodFlag];

% extract the essential data and
% sort instruments by depth
lenSampleData = length(sample_data);
instrumentDesc = cell(lenSampleData, 1);
hLineVar = nan(lenSampleData, 1);
metaDepth = nan(lenSampleData, 1);
xMin = nan(lenSampleData, 1);
xMax = nan(lenSampleData, 1);
dataVar = nan(lenSampleData,800000);
timeVar = dataVar;
isPlottable = false;

backgroundColor = [0.85 0.85 0.85];

for i=1:lenSampleData
    %only look at instruments with pressure
    iPresRel    = getVar(sample_data{i}.variables, 'PRES_REL');
    iPres       = getVar(sample_data{i}.variables, 'PRES');
    if (iPresRel==0 && iPres==0)
        continue;
    end
    if iPresRel
        data = sample_data{i}.variables{iPresRel}.data;
    else
        data = sample_data{i}.variables{iPres}.data - 14.7*0.689476; % let's apply SeaBird's atmospheric correction
        iPresRel = iPres;
    end
    
    iTime = getVar(sample_data{i}.dimensions, 'TIME');
    time = sample_data{i}.dimensions{iTime}.data;
    
    %calculate depth
    iLat = getVar(sample_data{i}.variables, 'LATITUDE');
    if isempty(iLat)
        error(['Depth calculation imposible: no latitude documented for ' sample_data{i}.toolbox_input_file ...
            ' serial number ' sample_data{i}.instrument_serial_number]);
    end
    data = -gsw_z_from_p(data, sample_data{i}.variables{iLat}.data);
    
    iGood = true(size(data));
        
    if isQC
        %get time and var QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        presFlags = sample_data{i}.variables{iPresRel}.flags;
        
        iGood = ismember(timeFlags, goodFlags) ...
            & ismember(presFlags, goodFlags); 
    end
    
    if all(~iGood) && isQC
        fprintf('%s\n', ['Warning : in ' sample_data{i}.toolbox_input_file ...
            ', there is not any pressure data with good flags.']);
        continue;
    else
        isPlottable = true;
    end

    data = data(iGood);
    time = time(iGood);
    
    %save the data into a holding matrix so we don't have to loop over the
    %sample_data matrix again.
    dataVar(i,1:length(data)) = data;
    timeVar(i,1:length(time)) = time;
    
    if ~isempty(sample_data{i}.meta.depth)
        metaDepth(i) = sample_data{i}.meta.depth;
    elseif ~isempty(sample_data{i}.instrument_nominal_depth)
        metaDepth(i) = sample_data{i}.instrument_nominal_depth;
    else
        metaDepth(i) = NaN;
    end
    
    xMin(i) = min(time);
    xMax(i) = max(time);
    % instrument description
    if ~isempty(strtrim(sample_data{(i)}.instrument))
        instrumentDesc{i} = sample_data{(i)}.instrument;
    elseif ~isempty(sample_data{(i)}.toolbox_input_file)
        [~, instrumentDesc{i}] = fileparts(sample_data{(i)}.toolbox_input_file);
    end
    
    instrumentSN = '';
    if ~isempty(strtrim(sample_data{(i)}.instrument_serial_number))
        instrumentSN = [' - ' sample_data{(i)}.instrument_serial_number];
    end
    
    instrumentDesc{i} = [strrep(instrumentDesc{i}, '_', ' ') ' (' num2str(metaDepth((i))) 'm' instrumentSN ')'];
end

if ~isPlottable
    return;
end

%only look at indexes with pres_rel
[metaDepth, iSort] = sort(metaDepth);
dataVar = dataVar(iSort,:);
timeVar = timeVar(iSort,:);
sample_data = sample_data(iSort);
instrumentDesc = instrumentDesc(iSort);
%delete non-pressure instrument information
dataVarTmp = dataVar;
dataVarTmp(isnan(dataVar)) = 0;
ibad = sum(dataVarTmp,2)==0;
metaDepth(ibad) = [];
sample_data(ibad) = [];
dataVar(ibad,:) = [];
timeVar(ibad,:) = [];
instrumentDesc(ibad) = [];
xMin = min(xMin);
xMax = max(xMax);

instrumentDesc = [{'Make Model (nominal depth - instrument SN)'}; instrumentDesc];
hLineVar(1) = line(0, 0, 'Visible', 'off', 'LineStyle', 'none', 'Marker', 'none');

%now plot all the calculated depths on one plot to choose region for comparison:
%plot
fileName = genIMOSFileName(sample_data{1}, 'png');
visible = 'on';
if saveToFile, visible = 'off'; end
hFigPress = figure(...
    'Name',             title, ...
    'NumberTitle',      'off', ...
    'Visible',          visible, ...
    'OuterPosition',    monitorRect(iBigMonitor, :));

hAxPress     = subplot(2,1,1,'Parent', hFigPress);
hAxDepthDiff = subplot(2,1,2,'Parent', hFigPress);

%depth plot for selecting region to compare depth to planned depth
set(hAxPress, 'YDir', 'reverse')
set(get(hAxPress, 'XLabel'), 'String', 'Time');
set(get(hAxPress, 'YLabel'), 'String', ['DEPTH (' varUnit ')'], 'Interpreter', 'none');
set(get(hAxPress, 'Title'), 'String', 'Depth', 'Interpreter', 'none');
set(hAxPress, 'XTick', (xMin:(xMax-xMin)/4:xMax));
set(hAxPress, 'XLim', [xMin, xMax]);
hold(hAxPress, 'on');

%Actual depth minus planned depth
set(get(hAxDepthDiff, 'XLabel'), 'String', 'Planned Depth (m)');
set(get(hAxDepthDiff, 'YLabel'), 'String', ['Actual Depth - Planned Depth (' varUnit ')'], 'Interpreter', 'none');
set(get(hAxDepthDiff, 'Title'), 'String', ...
    ['Differences from planned depth for ' sample_data{1}.meta.site_name] , 'Interpreter', 'none');
hold(hAxDepthDiff, 'on');
grid(hAxDepthDiff, 'on');

% set background to be grey
set(hAxPress, 'Color', backgroundColor);
set(hAxDepthDiff, 'Color', backgroundColor);

%color map
lenMetaDepth = length(metaDepth);
try
    defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
    cMap = colormap(hAxPress, defaultColormapFh(lenMetaDepth));
catch e
    cMap = colormap(hAxPress, parula(lenMetaDepth));
end
% reverse the colorbar as we want surface instruments with warmer colors
cMap = flipud(cMap);

% dummy entry for first entry in legend
hLineVar(1) = plot(hAxPress, 0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)

%now plot the data:Have to do it one at a time to get the colors right..
for i = 1:lenMetaDepth
    hLineVar(i+1) = line(timeVar(i,:), ...
        dataVar(i,:), ...
        'Color', cMap(i,:),...
        'LineStyle', '-',...
        'Parent', hAxPress);
end

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(hAxPress, ...
    'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
    'XGrid',        'on', ...
    'YGrid',        'on', ...
    'Layer',        'top');

if isPlottable    
    datetick(hAxPress, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend, maximum 3 columns
    fontSizeAx = get(hAxPress,'FontSize');
    fontSizeLb = get(get(hAxPress,'XLabel'),'FontSize');
    xscale = 0.9;
    if numel(instrumentDesc) < 4
        nCols = 1;
    elseif numel(instrumentDesc) < 8
        nCols = 2;
    else
        nCols = 3;
        fontSizeAx = fontSizeAx - 1;
        xscale = 0.75;
    end
    hYBuffer = 1.1 * (2*(fontSizeAx + fontSizeLb));
    hLegend = legendflex(hAxPress, instrumentDesc,...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols,...
        'FontSize', fontSizeAx,...
        'xscale', xscale);
    posAx = get(hAxPress, 'Position');
    set(hLegend, 'Units', 'Normalized', 'color', backgroundColor);

    % for some reason this call brings everything back together while it
    % shouldn't have moved previously anyway...
     set(hAxPress, 'Position', posAx);
end

%Ask for the user to select the region they would like to use for
%comparison
%This could be done better, with more finesse - could allow zooming in
%before going straight to the time period selection. For now, this will do.
hMsgbox = msgbox('Select (drag & drop) a time period on the top graph for comparison, preferably at the start of deployment, when the mooring is standing vertical', 'Time Period Selection', 'help', 'modal');
uiwait(hMsgbox);

%select the area to use for comparison
[x, ~] = select_points(hAxPress);

%now plot the difference from planned depth data:
iGood = timeVar >= x(1) & timeVar <= x(2);
dataVar(~iGood) = NaN;
minDep = min(dataVar,[],2);

scatter(hAxDepthDiff, ...
    metaDepth, ...
    minDep - metaDepth, ...
    15, ...
    cMap, ...
    'filled');

instrumentDesc(1) = [];
text(metaDepth + 1, (minDep - metaDepth), instrumentDesc, ...
    'Parent', hAxDepthDiff)
        
if isPlottable
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        fastSaveas(hFigPress, fullfile(exportDir, fileName));
        
        close(hFigPress);
    end
end

end