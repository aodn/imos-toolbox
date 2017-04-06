function checkMooringPresDiffs(sample_data, iSampleMenu, isQC, saveToFile, exportDir)
%CHECKMOORINGPRESDIFFS Opens a new window where the pressure
% variable collected by the selected intrument is plotted, and the difference
% in pressure from this instrument to adjacent instruments is plotted.
%
% Inputs:
%   sample_data - cell array of structs containing the entire data set and dimension data.
%
%   iSampleMenu - current Value of sampleMenu.
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
narginchk(5,5);

if ~iscell(sample_data),    error('sample_data must be a cell array');  end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

presRelCode = 'PRES_REL';
presCode = 'PRES';
varTitle = imosParameters(presRelCode, 'long_name');
varUnit = imosParameters(presRelCode, 'uom');

stringQC = 'all';
if isQC, stringQC = 'only good and non QC''d'; end

title = [sample_data{1}.deployment_code ' mooring ' stringQC ' ' varTitle ' (' varUnit ') differences'];

% retrieve good flag values
qcSet     = str2double(readProperty('toolbox.qc_set'));
rawFlag   = imosQCFlag('raw', qcSet, 'flag');
goodFlag  = imosQCFlag('good', qcSet, 'flag');
pGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
goodFlags = [rawFlag, goodFlag, pGoodFlag];

% sort instruments by depth
lenSampleData = length(sample_data);
instrumentDesc = cell(lenSampleData, 1);
metaDepth   = nan(lenSampleData, 1);
xMin        = nan(lenSampleData, 1);
xMax        = nan(lenSampleData, 1);
iPresRel    = nan(lenSampleData, 1);
iPres       = nan(lenSampleData, 1);
for i=1:lenSampleData
    if ~isempty(sample_data{i}.meta.depth)
        metaDepth(i) = sample_data{i}.meta.depth;
    elseif ~isempty(sample_data{i}.instrument_nominal_depth)
        metaDepth(i) = sample_data{i}.instrument_nominal_depth;
    else
        metaDepth(i) = NaN;
    end
    
    % instrument description
    if ~isempty(strtrim(sample_data{i}.instrument))
        instrumentDesc{i} = sample_data{i}.instrument;
    elseif ~isempty(sample_data{i}.toolbox_input_file)
        [~, instrumentDesc{i}] = fileparts(sample_data{i}.toolbox_input_file);
    end

    instrumentSN = '';
    if ~isempty(strtrim(sample_data{i}.instrument_serial_number))
        instrumentSN = [' - ' sample_data{i}.instrument_serial_number];
    end
    
    instrumentDesc{i} = [strrep(instrumentDesc{i}, '_', ' ') ' (' num2str(metaDepth(i)) 'm' instrumentSN ')'];

    iTime = getVar(sample_data{i}.dimensions, 'TIME');
    %check for pressure
    iPresRel(i) = getVar(sample_data{i}.variables, presRelCode);
    iPres(i)    = getVar(sample_data{i}.variables, presCode);
    
    xMin(i) = min(sample_data{i}.dimensions{iTime}.data);
    xMax(i) = max(sample_data{i}.dimensions{iTime}.data);
end
%only look at indexes with pres_rel or pres
[metaDepth, iSort] = sort(metaDepth);
sample_data     = sample_data(iSort);
instrumentDesc  = instrumentDesc(iSort);
iPresRel        = iPresRel(iSort);
iPres           = iPres(iSort);

iSort(iPresRel==0 & iPres==0)           = []; 
metaDepth(iPresRel==0 & iPres==0)       = [];
instrumentDesc(iPresRel==0 & iPres==0)  = [];
sample_data(iPresRel==0 & iPres==0)     = [];

xMin = min(xMin);
xMax = max(xMax);

%first find the instrument of interest:
iCurrSam = find(iSort == iSampleMenu);

hLineVar = nan(length(metaDepth), 1);
hLineVar2 = hLineVar;

isPlottable = false;

backgroundColor = [0.75 0.75 0.75];

%plot
fileName = genIMOSFileName(sample_data{iCurrSam}, 'png');
hFigPressDiff = figure(...
    'Name', title, ...
    'NumberTitle','off', ...
    'OuterPosition', monitorRect(iBigMonitor, :));

% create uipanel within figure so that screencapture can be
% used on the plot only and without capturing all of the figure
% (including buttons, menus...)
hPanelMooringVar = uipanel('Parent', hFigPressDiff);

%pressure plot
hAxPress = subplot(2,1,1,'Parent', hPanelMooringVar);
set(hAxPress, 'YDir', 'reverse')
set(get(hAxPress, 'XLabel'), 'String', 'Time');
set(get(hAxPress, 'YLabel'), 'String', [presRelCode ' (' varUnit ')'], 'Interpreter', 'none');
set(get(hAxPress, 'Title'), 'String', [varTitle '( ' varUnit ')'], 'Interpreter', 'none');
set(hAxPress, 'XTick', (xMin:(xMax-xMin)/4:xMax));
set(hAxPress, 'XLim', [xMin, xMax]);
hold(hAxPress, 'on');

%Pressure diff plot
hAxPressDiff = subplot(2,1,2,'Parent', hPanelMooringVar);
set(get(hAxPressDiff, 'XLabel'), 'String', 'Time');
set(get(hAxPressDiff, 'YLabel'), 'String', ['Pressure differences (' varUnit ')'], 'Interpreter', 'none');
set(get(hAxPressDiff, 'Title'), 'String', ...
    ['Pressure differences in ' varUnit ' (minus respective median over 1st quarter) between ' instrumentDesc{iCurrSam} ' (in black above) and nearest neighbours'] , 'Interpreter', 'none');
set(hAxPressDiff, 'XTick', (xMin:(xMax-xMin)/4:xMax));
set(hAxPressDiff, 'XLim', [xMin, xMax]);
hold(hAxPressDiff, 'on');

linkaxes([hAxPressDiff,hAxPress],'x')

%zero line
line([xMin, xMax], [0, 0], 'Color', 'black');

%now plot the data of interest:
iCurrTime = getVar(sample_data{iCurrSam}.dimensions, 'TIME');
curSamTime = sample_data{iCurrSam}.dimensions{iCurrTime}.data;

iCurrPresRel = getVar(sample_data{iCurrSam}.variables, presRelCode);
iCurrPres    = getVar(sample_data{iCurrSam}.variables, presCode);
if iCurrPresRel
    curSamPresRel = sample_data{iCurrSam}.variables{iCurrPresRel}.data;
else
    curSamPresRel = sample_data{iCurrSam}.variables{iCurrPres}.data - 14.7*0.689476; % let's apply SeaBird's atmospheric correction
    iCurrPresRel = iCurrPres;
end

iGood = true(size(curSamPresRel));
if isQC
    %get time and var QC information
    timeFlags = sample_data{iCurrSam}.dimensions{iCurrTime}.flags;
    varFlags = sample_data{iCurrSam}.variables{iCurrPresRel}.flags;
    
    iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
end

curSamTime(~iGood)      = NaN;
curSamPresRel(~iGood)   = NaN;

%now get the adjacent instruments based on planned depth (up to 4 nearest)
metaDepthCurrSam = metaDepth(iCurrSam);
[~, iOthers] = sort(abs(metaDepthCurrSam - metaDepth));
nOthers = length(iOthers);
nOthersMax = 5; % includes current sample
if nOthers > nOthersMax
    iOthers = iOthers(1:nOthersMax);
    nOthers = nOthersMax;
end

%color map
% no need to reverse the colorbar since instruments are plotted from
% nearest (blue) to farthest (yellow)
try
    defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
    cMap = colormap(hAxPress, defaultColormapFh(nOthers));
catch e
    cMap = colormap(hAxPress, parula(nOthers));
end
% current sample is black
cMap(iOthers == iCurrSam, :) = [0, 0, 0];

%now add the other data:
for i=1:nOthers
    %look for time and relevant variable
    iOtherTime    = getVar(sample_data{iOthers(i)}.dimensions, 'TIME');
    otherSamTime  = sample_data{iOthers(i)}.dimensions{iOtherTime}.data;
    
    iOtherPresRel = getVar(sample_data{iOthers(i)}.variables, presRelCode);
    iOtherPres    = getVar(sample_data{iOthers(i)}.variables, presCode);
    if iOtherPresRel
        otherSamPresRel = sample_data{iOthers(i)}.variables{iOtherPresRel}.data;
    else
        otherSamPresRel = sample_data{iOthers(i)}.variables{iOtherPres}.data - 14.7*0.689476; % let's apply SeaBird's atmospheric correction
        iOtherPresRel = iOtherPres;
    end

    iGood = true(size(otherSamPresRel));
    if isQC
        %get time and var QC information
        timeFlags = sample_data{iOthers(i)}.dimensions{iOtherTime}.flags;
        varFlags = sample_data{iOthers(i)}.variables{iOtherPresRel}.flags;
        
        iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
    end
    
    if all(~iGood) && isQC
        fprintf('%s\n', ['Warning : in ' sample_data{iOthers(i)}.toolbox_input_file ...
            ', there is not any pressure data with good flags.']);
        continue;
    else
        isPlottable = true;
        
        otherSamTime(~iGood) = [];
        otherSamPresRel(~iGood) = [];
        
        %add pressure to the pressure plot
        hLineVar(iOthers(i)) = line(otherSamTime, ...
            otherSamPresRel, ...
            'Color',     cMap(i, :), ...
            'LineStyle', '-', ...
            'Parent',    hAxPress);
                
        %now put the data on the same timebase as the instrument of
        %interest
        otherSamPresRel = interp1(otherSamTime, otherSamPresRel, curSamTime);
        
        curSamTimeFirstQuarter = min(curSamTime) + (max(curSamTime) - min(curSamTime))/4;
        iCurSamTimeFirstQuarter = curSamTime < curSamTimeFirstQuarter;
        
        otherSamPresRelMedianFirstQuarter = median(otherSamPresRel(~isnan(otherSamPresRel) & iCurSamTimeFirstQuarter));
        curSamPresRelMedianFirstQuarter = median(curSamPresRel(~isnan(curSamPresRel) & iCurSamTimeFirstQuarter));
        
        pdiff = (curSamPresRel - curSamPresRelMedianFirstQuarter) - (otherSamPresRel - otherSamPresRelMedianFirstQuarter);
        
        hLineVar2(iOthers(i)) = line(curSamTime, ...
            pdiff, ...
            'Color',     cMap(i, :), ...
            'LineStyle', '-', ...
            'Parent',    hAxPressDiff);
        
        % set background to be grey
        set(hAxPress, 'Color', backgroundColor)
        set(hAxPressDiff, 'Color', backgroundColor)
    end
end

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(hAxPress, ...
    'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
    'XGrid',        'on', ...
    'YGrid',        'on', ...
    'Layer',        'top');

set(hAxPressDiff, ...
    'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
    'XGrid',        'on', ...
    'YGrid',        'on', ...
    'Layer',        'top');

if isPlottable
    iNan = isnan(hLineVar);
    if any(iNan)
        hLineVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    iOthers = iOthers - (min(iOthers)-1);
        
    datetick(hAxPressDiff, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
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
    hLegend = legendflex(hAxPress, instrumentDesc(iOthers),...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols,...
        'FontSize', fontSizeAx,...
        'xscale', xscale, ...
        'parent', hPanelMooringVar);
    posAx = get(hAxPress, 'Position');
    set(hLegend, 'Units', 'Normalized', 'color', backgroundColor);

    % for some reason this call brings everything back together while it
    % shouldn't have moved previously anyway...
     set(hAxPress, 'Position', posAx);
    
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        fastSaveas(hFigPressDiff, hPanelMooringVar, fullfile(exportDir, fileName));
        
        close(hFigPressDiff);
    end
end

end