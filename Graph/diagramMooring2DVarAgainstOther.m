function diagramMooring2DVarAgainstOther(sample_data, varName, yAxisVarName, isQC, saveToFile, exportDir)
%DIAGRAMMOORING2DVARAGAINSTDEPTH Opens a new window where the selected 2D
% variable collected by all the intruments on the mooring are plotted in a diagram plot.
%
% Inputs:
%   sample_data - cell array of structs containing the entire data set and dimension data.
%
%   varName     - string containing the IMOS code for requested X parameter.
%
%   yAxisVarName- string containing the IMOS code for requested Y parameter.
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
narginchk(6,6);

if ~iscell(sample_data),    error('sample_data must be a cell array');  end
if ~ischar(varName),        error('varName must be a string');          end
if ~ischar(yAxisVarName),   error('yAxisVarName must be a string');     end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL', yAxisVarName})), return; end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

varTitle = imosParameters(varName, 'long_name');
varUnit  = imosParameters(varName, 'uom');

yAxisVarTitle = imosParameters(yAxisVarName, 'long_name');
yAxisVarUnit  = imosParameters(yAxisVarName, 'uom');

stringQC = 'all';
if isQC, stringQC = 'only good and non QC''d'; end

title = [sample_data{1}.deployment_code ' ' stringQC ' ' varTitle ' / ' yAxisVarTitle ' diagram'];

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
    iYAxisVar = getVar(sample_data{i}.variables, yAxisVarName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
    
    % the variables exist
    if iVar && iYAxisVar
        if isQC
            %get time and var QC information
            timeFlags = sample_data{i}.dimensions{iTime}.flags;
            varFlags = sample_data{i}.variables{iVar}.flags;
            yAxisVarFlags = sample_data{i}.variables{iYAxisVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            
            iGoodYAxisVar = ismember(yAxisVarFlags, goodFlags);
            
            if size(iGoodYAxisVar) == size(iGoodTime)
                iGoodTime = iGoodTime & iGoodYAxisVar;
            end
        
            iGood = repmat(iGoodTime, [1, size(sample_data{i}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{i}.variables{iVar}.data);
            
            if size(iGoodYAxisVar) == size(iGood)
                iGood = iGood & iGoodYAxisVar;
            end
        end
        
        if any(any(iGood))
            xMin(i) = min(sample_data{i}.variables{iVar}.data(iGood));
            xMax(i) = max(sample_data{i}.variables{iVar}.data(iGood));
        end
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
cLimMin = NaN;
cLimMax = NaN;
isPlottable = false(1, lenSampleData);
for i=1:lenSampleData
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
    iHeight = getVar(sample_data{iSort(i)}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if iHeight == 0, iHeight = getVar(sample_data{iSort(i)}.dimensions, 'DIST_ALONG_BEAMS'); end % is equivalent when tilt is negligeable
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar && iYAxisVar && iHeight && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) > 1 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 3) == 1 % we're plotting ADCP 2D variables with DEPTH variable.
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            yAxisVarFlags = sample_data{iSort(i)}.variables{iYAxisVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            
            iGoodYAxisVar = ismember(yAxisVarFlags, goodFlags);
            
            if size(iGoodYAxisVar) == size(iGoodTime)
                iGoodTime = iGoodTime & iGoodYAxisVar;
            end
            
            if iDepth
                depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                iGoodTime = iGoodTime & ismember(depthFlags, goodFlags);
            end
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
            
            if size(iGoodYAxisVar) == size(iGood)
                iGood = iGood & iGoodYAxisVar;
            end
        end
        
        if any(any(iGood))
            isPlottable(i) = true;
            if ~iDepth
                iDepth = getVar(sample_data{iSort(i)}.variables, 'NOMINAL_DEPTH');
            end
            iGoodHeight = any(iGood, 1);
            cLimMin = min(cLimMin, min(sample_data{iSort(i)}.variables{iDepth}.data(iGoodTime) - max(sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight))));
            cLimMax = max(cLimMax, max(sample_data{iSort(i)}.variables{iDepth}.data(iGoodTime) - min(sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight))));
        end
        
    elseif iVar && iYAxisVar && ...
            any(strncmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3', 'VEL4'}, 4)) && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 % we're plotting current metre 1D variables with DEPTH variable.
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            yAxisVarFlags = sample_data{iSort(i)}.variables{iYAxisVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            
            iGoodYAxisVar = ismember(yAxisVarFlags, goodFlags);
            
            if size(iGoodYAxisVar) == size(iGoodTime)
                iGoodTime = iGoodTime & iGoodYAxisVar;
            end
            
            if iDepth
                depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                iGoodTime = iGoodTime & ismember(depthFlags, goodFlags);
            end
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
            
            if size(iGoodYAxisVar) == size(iGood)
                iGood = iGood & iGoodYAxisVar;
            end
        end
        
        if any(any(iGood))
            isPlottable(i) = true;
            if ~iDepth
                iDepth = getVar(sample_data{iSort(i)}.variables, 'NOMINAL_DEPTH');
            end
            cLimMin = min(cLimMin, min(sample_data{iSort(i)}.variables{iDepth}.data(iGoodTime)));
            cLimMax = max(cLimMax, max(sample_data{iSort(i)}.variables{iDepth}.data(iGoodTime)));
        end
    end
end

backgroundColor = [0.85 0.85 0.85];

if any(isPlottable)
    % collect visualQC config
    try
        fastScatter = eval(readProperty('visualQC.fastScatter'));
    catch e %#ok<NASGU>
        fastScatter = true;
    end
    
    % define cMap, cLim and cType
    try
        nColors =  str2double(readProperty('visualQC.ncolors'));
        defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
        cMap = defaultColormapFh(nColors);
    catch e
        nColors = 64;
        cMap = parula(nColors);
    end
    cType = '';
    CLim = [cLimMin cLimMax];
    
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
        iYAxisVar = getVar(sample_data{iSort(i)}.variables, yAxisVarName);
        
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
            
                if strcmpi(yAxisVarName, 'DEPTH')
                    set(hAxMooringVar, 'YDir', 'reverse');
                end
                set(get(hAxMooringVar, 'XLabel'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
                set(get(hAxMooringVar, 'YLabel'), 'String', [yAxisVarName ' (' yAxisVarUnit ')'], 'Interpreter', 'none');
                set(get(hAxMooringVar, 'Title'), 'String', title, 'Interpreter', 'none');
                set(hAxMooringVar, 'XLim', [xMin, xMax]); % otherwise figure sets extra margin
                hold(hAxMooringVar, 'on');
                
                % dummy entry for first entry in legend
                hScatterVar(1) = plot(0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)
                
                % set data cursor mode custom display
                dcm_obj = datacursormode(hFigMooringVar);
                set(dcm_obj, 'UpdateFcn', {@customDcm, sample_data}, 'SnapToDataVertex','on');
                
                colormap(hAxMooringVar, flipud(cMap)); % DEPTH
                
                if ~strcmpi(yAxisVarName, 'DEPTH')
                    % colorbar not needed when Y axis is already DEPTH
                    hCBar = colorbar('peer', hAxMooringVar);
                    set(get(hCBar, 'Title'), 'String', 'DEPTH (m)', 'Interpreter', 'none');
                end
                
                initiateFigure = false;
            end
            
            iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
            iGoodTime = true(size(sample_data{iSort(i)}.dimensions{iTime}.data));
            iGoodDepth = iGoodTime;
            
            if isQC
                %get time and var QC information
                timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
                varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
                yAxisVarFlags = sample_data{iSort(i)}.variables{iYAxisVar}.flags;
                varValues = sample_data{iSort(i)}.variables{iVar}.data;
                yAxisVarValues = sample_data{iSort(i)}.variables{iYAxisVar}.data;
                
                if iDepth
                    depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                    iGoodDepth = ismember(depthFlags, goodFlags);
                end
                
                iGoodTime = ismember(timeFlags, goodFlags);
                
                iGoodYAxisVar = ismember(yAxisVarFlags, goodFlags) & ~isnan(yAxisVarValues) ;
            
                if size(iGoodYAxisVar) == size(iGoodTime)
                    iGoodTime = iGoodTime & iGoodYAxisVar;
                end
                
                iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
                iGood = iGood & ismember(varFlags, goodFlags) & ~isnan(varValues);
                
                if size(iGoodYAxisVar) == size(iGood)
                    iGood = iGood & iGoodYAxisVar;
                end
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
                xScatter = sample_data{iSort(i)}.variables{iVar}.data;
                xScatter(~iGood) = NaN;
                
                if iHeight
                    zScatter = sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight);
                else
                    zScatter = 0;
                end
                
                if iDepth && ~strcmpi(yAxisVarName, 'DEPTH')
                    dataDepth = sample_data{iSort(i)}.variables{iDepth}.data;
                else
                    % nominal depth as a scatter color is mor informative
                    % when Y axis is already DEPTH
                    if isfield(sample_data{iSort(i)}, 'instrument_nominal_depth')
                        if ~isempty(sample_data{iSort(i)}.instrument_nominal_depth)
                            dataDepth = sample_data{iSort(i)}.instrument_nominal_depth*ones(size(iGoodTime));
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
                
                yScatter = sample_data{iSort(i)}.variables{iYAxisVar}.data;
                yScatter(~iGoodYAxisVar) = NaN;
                
                for j=1:nGoodHeight
                    % data for customDcm
                    userData.idx = iSort(i);
                    userData.jHeight = j;
                    userData.xName = varName;
                    userData.yName = yAxisVarName;
                    
                    if strcmpi(yAxisVarName, 'DEPTH')
                        yScatterToPlot = yScatter - zScatter(j);
                    else
                        yScatterToPlot = yScatter;
                    end
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
                            xScatter(:, j), ...
                            yScatterToPlot, ...
                            dataDepth - zScatter(j), ...
                            markerStyle{mod(i, lenMarkerStyle)+1}, ...
                            CLim, ...
                            'DisplayName', instrumentDesc{i+1}, ...
                            'MarkerSize',  2.5, ...
                            'UserData',    userData);
                    else
                        % faster than scatter, but legend requires adjusting
                        h = fastScatterMesh( hAxMooringVar, ...
                            xScatter(:, j), ...
                            yScatterToPlot, ...
                            dataDepth - zScatter(j), ...
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
                % above color data
                set(hAxMooringVar, ...
                    'XGrid',        'on', ...
                    'YGrid',        'on', ...
                    'Layer',        'top');
                
                % set background to be grey
                set(hAxMooringVar, 'Color', backgroundColor)
            end
           
            if strcmpi(yAxisVarName, 'DEPTH')
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
        fileName = strrep(fileName, '_PARAM_', ['_' varName '_vs_' yAxisVarName '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_vs_[OTHER-PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_DIAGRAM_');
        
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
            xStr = [num2str(posClic(1)) ' ' xUnits];
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
            yStr = [num2str(posClic(2)) ' ' yUnits]; %num2str(posClic(2),4)
        catch
            yStr = 'NO DATA';
        end
        
        try
            datacursorText = {dStr,...
                [xName ': ' xStr],...
                [yName ': ' yStr]};
            % debug info
            %datacursorText{end+1} = ['DataIndex : ' num2str(dataIndex)];
            %datacursorText{end+1} = ['idx: ' num2str(idx)];
            %datacursorText{end+1} = ['minClim: ' num2str(minClim)];
            %datacursorText{end+1} = ['maxClim: ' num2str(maxClim)];
        catch
            datacursorText = {'NO DATA'};
        end
    end
end