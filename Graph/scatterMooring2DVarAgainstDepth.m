function scatterMooring2DVarAgainstDepth(sample_data, varName, isQC, saveToFile, exportDir)
%SCATTERMOORING2DVARAGAINSTDEPTH Opens a new window where the selected 2D
% variable collected by all the intruments on the mooring are plotted in a timeseries plot.
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
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
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

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(5,5);

if ~iscell(sample_data),    error('sample_data must be a cell array');  end
if ~ischar(varName),        error('varName must be a string');          end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'}))
    return;
end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

varTitle = imosParameters(varName, 'long_name');
varUnit = imosParameters(varName, 'uom');

stringQC = 'all';
if isQC, stringQC = 'only good and non QC''d'; end

title = [sample_data{1}.deployment_code ' mooring''s instruments ' stringQC ' ' varTitle];

% retrieve good flag values
qcSet     = str2double(readProperty('toolbox.qc_set'));
rawFlag   = imosQCFlag('raw', qcSet, 'flag');
goodFlag  = imosQCFlag('good', qcSet, 'flag');
pGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
goodFlags = [rawFlag, goodFlag, pGoodFlag];

% sort instruments by depth
lenSampleData = length(sample_data);
metaDepth = nan(lenSampleData, 1);
xMin = nan(lenSampleData, 1);
xMax = nan(lenSampleData, 1);

for i=1:lenSampleData
    if ~isempty(sample_data{i}.meta.depth)
        metaDepth(i) = sample_data{i}.meta.depth;
    elseif ~isempty(sample_data{i}.instrument_nominal_depth)
        metaDepth(i) = sample_data{i}.instrument_nominal_depth;
    else
        metaDepth(i) = NaN;
    end
    iTime = getVar(sample_data{i}.dimensions, 'TIME');
    iVar = getVar(sample_data{i}.variables, varName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
    
    if isQC && iVar
        %get time and var QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        varFlags = sample_data{i}.variables{iVar}.flags;
        
        iGoodTime = ismember(timeFlags, goodFlags);
        
        iGood = repmat(iGoodTime, [1, size(sample_data{i}.variables{iVar}.data, 2)]);
        iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{i}.variables{iVar}.data);
        iGood = max(iGood, [], 2); % we only need one good bin
    end
    
    if iVar
        if all(~iGood)
            continue;
        end
        xMin(i) = min(sample_data{i}.dimensions{iTime}.data(iGood));
        xMax(i) = max(sample_data{i}.dimensions{iTime}.data(iGood));
    end
end
[metaDepth, iSort] = sort(metaDepth);
xMin = min(xMin);
xMax = max(xMax);

markerStyle = {'+', 'o', '*', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
lenMarkerStyle = length(markerStyle);

instrumentDesc = cell(lenSampleData + 1, 1);
hScatterVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'Make Model (nominal depth - instrument SN)';

% we need to go through every instruments to figure out the CLim properties
% on which the subset plots happen below.
yLimMin = NaN;
yLimMax = NaN;
isPlottable = false(1, lenSampleData);
for i=1:lenSampleData
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iHeight = getVar(sample_data{iSort(i)}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if iHeight == 0, iHeight = getVar(sample_data{iSort(i)}.dimensions, 'DIST_ALONG_BEAMS'); end % is equivalent when tilt is negligeable
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && iHeight > 0 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) > 1 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 3) == 1 % we're plotting ADCP 2D variables with DEPTH variable.
        isPlottable(i) = true;
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
        end
        
        if any(any(iGood))
            yLimMin = min(yLimMin, min(min(sample_data{iSort(i)}.variables{iVar}.data(iGood))));
            yLimMax = max(yLimMax, max(max(sample_data{iSort(i)}.variables{iVar}.data(iGood))));
        end
        
    elseif iVar > 0 && ...
            any(strncmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3'}, 4)) && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 % we're plotting current metre 1D variables with DEPTH variable.
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
        end
        
        if any(any(iGood))
            isPlottable(i) = true;
            yLimMin = min(yLimMin, min(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
            yLimMax = max(yLimMax, max(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
        end
    end
end

backgroundColor = [0.75 0.75 0.75];

if any(isPlottable)
    % collect visualQC config
    try
        fastScatter = eval(readProperty('visualQC.fastScatter'));
    catch e %#ok<NASGU>
        fastScatter = true;
    end
    
    % define cMap, cLim and cType per parameter
    switch varName(1:4)
        case {'UCUR', 'VCUR', 'WCUR', 'ECUR', 'VEL1', 'VEL2', 'VEL3'}   % 0 centred parameters
            cMap = 'r_b';
            cType = 'centeredOnZero';
            CLim = [-max(abs(yLimMin), abs(yLimMax)) max(abs(yLimMax), abs(yLimMin))];
        case {'CDIR', 'SSWD'}           % directions [0; 360[
            cMap = 'rkbwr';
            cType = 'direction';
            CLim = [0 360];
        case {'CSPD'}                   % [0; oo[ paremeters
            try
                nColors =  str2double(readProperty('visualQC.ncolors'));
                defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                cMap = defaultColormapFh(nColors);
            catch e
                nColors = 64;
                cMap = parula(nColors);
            end
            cType = 'positiveFromZero';
            CLim = [0 yLimMax];
        otherwise
            try
                nColors =  str2double(readProperty('visualQC.ncolors'));
                defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                cMap = defaultColormapFh(nColors);
            catch e
                nColors = 64;
                cMap = parula(nColors);
            end
            cType = '';
            CLim = [yLimMin yLimMax];
    end
    
    initiateFigure = true;
    for i=1:lenSampleData
        % instrument description
        if ~isempty(strtrim(sample_data{iSort(i)}.instrument))
            instrumentDesc{i + 1} = sample_data{iSort(i)}.instrument;
        elseif ~isempty(sample_data{iSort(i)}.toolbox_input_file)
            [~, instrumentDesc{i + 1}] = fileparts(sample_data{iSort(i)}.toolbox_input_file);
        end
        
        instrumentSN = '';
        if ~isempty(strtrim(sample_data{iSort(i)}.instrument_serial_number))
            instrumentSN = [' - ' sample_data{iSort(i)}.instrument_serial_number];
        end
        
        instrumentDesc{i + 1} = [strrep(instrumentDesc{i + 1}, '_', ' ') ' (' num2str(metaDepth(i)) 'm' instrumentSN ')'];
        
        %look for time and relevant variable
        iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
        iHeight = getVar(sample_data{iSort(i)}.dimensions, 'HEIGHT_ABOVE_SENSOR');
        if iHeight == 0, iHeight = getVar(sample_data{iSort(i)}.dimensions, 'DIST_ALONG_BEAMS'); end % is equivalent when tilt is negligeable
        iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
        iVar = getVar(sample_data{iSort(i)}.variables, varName);
        
        if isPlottable(i)
            if initiateFigure
                fileName = genIMOSFileName(sample_data{iSort(i)}, 'png');
                visible = 'on';
                if saveToFile, visible = 'off'; end
                hFigMooringVar = figure(...
                    'Name',             title, ...
                    'NumberTitle',      'off', ...
                    'Visible',          visible, ...
                    'OuterPosition',    monitorRect(iBigMonitor, :));
                
                hAxMooringVar = axes('Parent', hFigMooringVar);
            
                set(hAxMooringVar, 'YDir', 'reverse');
                set(get(hAxMooringVar, 'XLabel'), 'String', 'Time');
                set(get(hAxMooringVar, 'YLabel'), 'String', 'DEPTH (m)', 'Interpreter', 'none');
                set(get(hAxMooringVar, 'Title'), 'String', title, 'Interpreter', 'none');
                set(hAxMooringVar, 'XTick', (xMin:(xMax-xMin)/4:xMax));
                set(hAxMooringVar, 'XLim', [xMin, xMax]);
                hold(hAxMooringVar, 'on');
                
                % dummy entry for first entry in legend
                hScatterVar(1) = plot(0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)
                
                % set data cursor mode custom display
                dcm_obj = datacursormode(hFigMooringVar);
                set(dcm_obj, 'UpdateFcn', {@customDcm, sample_data}, 'SnapToDataVertex','on');
                
                % set zoom datetick update
                datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
                zoomH = zoom(hFigMooringVar);
                panH = pan(hFigMooringVar);
                set(zoomH,'ActionPostCallback',{@zoomDateTick, hAxMooringVar});
                set(panH,'ActionPostCallback',{@zoomDateTick, hAxMooringVar});
                
                hCBar = colorbar('peer', hAxMooringVar, 'YLim', CLim);
                colormap(hAxMooringVar, cMap);
                set(hAxMooringVar, 'CLim', CLim);
                
                if strcmpi(cType, 'direction')
                    set(hCBar, 'YTick', [0 90 180 270 360]);
                end
                
                set(get(hCBar, 'Title'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
                
                initiateFigure = false;
            end
            
            iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
            iGoodTime = true(size(sample_data{iSort(i)}.dimensions{iTime}.data));
            iGoodDepth = iGoodTime;
            
            if isQC
                %get time and var QC information
                timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
                varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
                varValues = sample_data{iSort(i)}.variables{iVar}.data;
                
                if iDepth
                    depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                    iGoodDepth = ismember(depthFlags, goodFlags);
                end
                
                iGoodTime = ismember(timeFlags, goodFlags);
                
                iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
                iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(varValues);
            end
            
            iGoodHeight = any(iGood, 1);
            nGoodHeight = sum(iGoodHeight);
            % nGoodHeight = nGoodHeight + 1;
            % iGoodHeight(nGoodHeight) = 1;
            
            if all(all(~iGood)) && isQC
                fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                    ', there is not any ' varName ' data with good flags.']);
                continue;
            else
                xScatter = sample_data{iSort(i)}.dimensions{iTime}.data;
                xScatter(~iGoodTime) = NaN;
                
                if iHeight > 0
                    yScatter = sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight);
                else
                    yScatter = 0;
                end
                
                if iDepth
                    dataDepth = sample_data{iSort(i)}.variables{iDepth}.data;
                else
                    if isfield(sample_data{iSort(i)}, 'instrument_nominal_depth')
                        if ~isempty(sample_data{iSort(i)}.instrument_nominal_depth)
                            if iHeight == 0
                                dataDepth = sample_data{iSort(i)}.instrument_nominal_depth*ones(size(iGoodTime));
                            else
                                dataDepth = repmat(sample_data{iSort(i)}.instrument_nominal_depth + ...
                                    sample_data{iSort(i)}.dimensions{iHeight}.data, 1, length(iGoodTime));
                            end
                        else
                            fprintf('%s\n', ['Error : in ' sample_data{iSort(i)}.toolbox_input_file ...
                                ', global attribute instrument_nominal_depth is not documented.']);
                            continue;
                        end
                    else
                        fprintf('%s\n', ['Error : in ' sample_data{iSort(i)}.toolbox_input_file ...
                            ', global attribute instrument_nominal_depth is not documented.']);
                        continue;
                    end
                end
                dataDepth(~iGoodTime) = NaN;
                dataDepth(~iGoodDepth) = metaDepth(i);
                
                dataVar = sample_data{iSort(i)}.variables{iVar}.data;
                dataVar(~iGood) = NaN;
                
                for j=1:nGoodHeight
                    % data for customDcm
                    userData.idx = iSort(i);
                    userData.jHeight = j;
                    userData.xName = 'TIME';
                    userData.yName = 'DEPTH';
                    userData.zName = varName;
                    
                    if fastScatter
                        % for performance, we use plot (1 single handle object
                        % returned) rather than scatter (as many handles returned as
                        % points to plot). We plot as many subsets of the total amount
                        % of points as we want colors to be displayed. This is
                        % performed by the function plotclr.
                        
                        % !!! The result is such that the overlapping of points is dictated by
                        % the order of the colors to be plotted and not by the X axis order (from
                        % first to last) of the total points given. We choose an ordering from
                        % centre to both ends of colorbar in order to keep extreme colors visible
                        % though.
                        h = plotclr(hAxMooringVar, ...
                            xScatter, ...
                            dataDepth - yScatter(j), ...
                            dataVar(:, j), ...
                            markerStyle{mod(i, lenMarkerStyle)+1}, ...
                            CLim,...
                            'DisplayName', instrumentDesc{i+1}, ...
                            'MarkerSize',  2.5, ...
                            'UserData',    userData);
                    else
                        % faster than scatter, but legend requires adjusting
                        h = fastScatterMesh( hAxMooringVar, ...
                            xScatter, ...
                            dataDepth - yScatter(j), ...
                            dataVar(:, j), ...
                            CLim, ...
                            'Marker',      markerStyle{mod(i, lenMarkerStyle)+1}, ...
                            'DisplayName', instrumentDesc{i+1}, ...
                            'MarkerSize',  2.5, ...
                            'UserData',    userData);
                    end
                    clear('userData');
                    
                    if ~isempty(h), hScatterVar(i + 1) = h; end
                end
                
                % Let's redefine properties to make sure grid lines appear
                % above color data and XTick and XTickLabel haven't changed
                set(hAxMooringVar, ...
                    'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
                    'XGrid',        'on', ...
                    'YGrid',        'on', ...
                    'Layer',        'top');
                
                % set background to be grey
                set(hAxMooringVar, 'Color', backgroundColor)
            end
            
            % we plot the instrument nominal depth
            hNominalDepth = line([xMin, xMax], [metaDepth(i), metaDepth(i)], ...
                'Color', 'black');
            % turn off legend entry for this plot
            set(get(get(hNominalDepth,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
            % with 'HitTest' == 'off' plot should not be selectable but
            % just in case set idx = NaN for customDcm
            userData.idx = NaN;
            set(hNominalDepth, 'UserData', userData, 'HitTest', 'off');
            clear('userData');
        end
    end
else
    return;
end

if ~initiateFigure
    iNan = isnan(hScatterVar);
    if any(iNan)
        hScatterVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend horizontally, max 3 columns
    fontSizeAx = get(hAxMooringVar,'FontSize');
    fontSizeLb = get(get(hAxMooringVar,'XLabel'),'FontSize');
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
    hLegend = legendflex(hAxMooringVar,instrumentDesc,...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols,...
        'FontSize', fontSizeAx, ...
        'xscale',xscale);
    
    % if used mesh for scatter plot then have to clean up legend
    % entries
    entries = get(hLegend,'children');
    for ii = 1:numel(entries)
        if strcmpi(get(entries(ii),'Type'),'patch')
            XData = get(entries(ii),'XData');
            YData = get(entries(ii),'YData');
            %CData = get(entries(ii),'CData');
            set(entries(ii),'XData',repmat(mean(XData),size(XData)))
            set(entries(ii),'YData',repmat(mean(YData),size(XData)))
            %set(entries(ii),'CData',CData(1))
        end
    end
    posAx = get(hAxMooringVar, 'Position');
    set(hLegend, 'Units', 'Normalized', 'color', backgroundColor)
    posLh = get(hLegend, 'Position');
    if posLh(2) < 0
        set(hLegend, 'Position',[posLh(1), abs(posLh(2)), posLh(3), posLh(4)]);
        set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+2*abs(posLh(2)), posAx(3), posAx(4)-2*abs(posLh(2))]);
    else
        set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+abs(posLh(2)), posAx(3), posAx(4)-abs(posLh(2))]);
    end
    
    %     set(hLegend, 'Box', 'off', 'Color', 'none');
    
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_SCATTER_');
        
        fastSaveas(hFigMooringVar, fullfile(exportDir, fileName));
        
        close(hFigMooringVar);
    end
end

%%
    function datacursorText = customDcm(~, event_obj, sample_data)
        %customDcm : custom data tip display for 1D Var Against Depth plot
        %
        % Display the position of the data cursor
        % obj          Currently not used (empty)
        % event_obj    Handle to event object
        % datacursorText   Data cursor text string (string or cell array of strings).
        % sample_data : the data plotted, since only good data is plotted require
        % iGood passed in on UserData
        %
        % NOTES
        % - the multiple try catch blocks are there to trap and modifications of
        % the UserData field (by say an external function called before entry into
        % customDcm
        
        dataIndex = get(event_obj,'DataIndex');
        posClic = get(event_obj,'Position');
        
        target_obj=get(event_obj,'Target');
        userData = get(target_obj, 'UserData');
        
        % somehow selected nominal depth line plot
        if isnan(userData.idx), return; end
        
        sam = sample_data{userData.idx};
        
        xName = userData.xName;
        yName = userData.yName;
        zName = userData.zName;
        
        try
            dStr = get(target_obj,'DisplayName');
        catch
            dStr = 'UNKNOWN';
        end
        
        try
            % generalized case pass in a variable instead of a dimension
            ixVar = getVar(sam.dimensions, xName);
            if ixVar ~= 0
                xUnits  = sam.dimensions{ixVar}.units;
            else
                ixVar = getVar(sam.variables, xName);
                xUnits  = sam.variables{ixVar}.units;
            end
            if strcmp(xName, 'TIME')
                xStr = datestr(posClic(1),'dd-mm-yyyy HH:MM:SS.FFF');
            else
                xStr = [num2str(posClic(1)) ' ' xUnits];
            end
        catch
            xStr = 'NO DATA';
        end
        
        try
            % generalized case pass in a variable instead of a dimension
            iyVar = getVar(sam.dimensions, yName);
            if iyVar ~= 0
                yUnits  = sam.dimensions{iyVar}.units;
            else
                iyVar = getVar(sam.variables, yName);
                yUnits  = sam.variables{iyVar}.units;
            end
            if strcmp(yName, 'TIME')
                yStr = datestr(posClic(2),'dd-mm-yyyy HH:MM:SS.FFF');
            else
                yStr = [num2str(posClic(2)) ' ' yUnits]; %num2str(posClic(2),4)
            end
        catch
            yStr = 'NO DATA';
        end
        
        try
            % generalized case pass in a variable instead of a dimension
            izVar = getVar(sam.dimensions, zName);
            if izVar ~= 0
                zUnits  = sam.dimensions{izVar}.units;
                zData = sam.dimensions{izVar}.data;
            else
                izVar = getVar(sam.variables, zName);
                zUnits  = sam.variables{izVar}.units;
                zData = sam.variables{izVar}.data;
            end
            
            iTime = getVar(sam.dimensions, 'TIME');
            timeData = sam.dimensions{iTime}.data;
            idx = find(abs(timeData-posClic(1))<eps(10));
            if strcmp(zName, 'TIME')
                zStr = datestr(zData(idx),'dd-mm-yyyy HH:MM:SS.FFF');
            else
                zStr = [num2str(zData(idx,userData.jHeight)) ' (' zUnits ')'];
            end
        catch
            zStr = 'NO DATA';
        end
        
        try
            datacursorText = {dStr,...
                [xName ': ' xStr],...
                [yName ': ' yStr],...
                [zName ': ' zStr]};
            % debug info
            %datacursorText{end+1} = ['DataIndex : ' num2str(dataIndex)];
            %datacursorText{end+1} = ['idx: ' num2str(idx)];
            %datacursorText{end+1} = ['minClim: ' num2str(minClim)];
            %datacursorText{end+1} = ['maxClim: ' num2str(maxClim)];
        catch
            datacursorText = {'NO DATA'};
        end
    end

%%
    function zoomDateTick(obj,event_obj,hAx)
        xLim = get(hAx, 'XLim');
        currXTicks = get(hAx, 'xtick');
        newXTicks = linspace(xLim(1), xLim(2), length(currXTicks));
        set(hAx, 'xtick', newXTicks);
        datetick(hAx,'x','dd-mm-yy HH:MM:SS','keepticks');
    end

end

