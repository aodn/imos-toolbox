function lineMooring1DVar(sample_data, varName, isQC, saveToFile, exportDir)
%LINEMOORING1DVAR Opens a new window where the selected 1D
% variables collected by all the intruments on the mooring are plotted.
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

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

if strcmp(varName, 'diff(TIME)')
    varName = 'TIME';
    typeVar = 'dimensions';
    varTitle = ['diff ' imosParameters(varName, 'long_name')];
    varUnit = 's';
else
    typeVar = 'variables';
    varTitle = imosParameters(varName, 'long_name');
    varUnit = imosParameters(varName, 'uom');
end

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
    iVar = getVar(sample_data{i}.(typeVar), varName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
    
    % the variable exists, is QC'd and is 1D
    if isQC && iVar && size(sample_data{i}.(typeVar){iVar}.data, 2) == 1
        %get time and var QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        varFlags = sample_data{i}.(typeVar){iVar}.flags;
        
        iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
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

% somehow could not get any data to plot, bail early
if any(isnan([xMin, xMax]))
    fprintf('%s\n', ['Warning : there is not any ' varName ' data in this deployment with good flags.']);
    return;
end

instrumentDesc = cell(lenSampleData + 1, 1);
hLineVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'Make Model (nominal depth - instrument SN)';

initiateFigure = true;
isPlottable = false;

backgroundColor = [1 1 1]; % white

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
    iVar = getVar(sample_data{iSort(i)}.(typeVar), varName);
    
    if iVar > 0 && size(sample_data{iSort(i)}.(typeVar){iVar}.data, 2) == 1 && ... % we're only plotting 1D variables but no current
            all(~strncmpi(sample_data{iSort(i)}.(typeVar){iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3', 'VEL4'}, 4))
        if initiateFigure
            fileName = genIMOSFileName(sample_data{iSort(i)}, 'png');
            visible = 'on';
            if saveToFile, visible = 'off'; end
            hFigMooringVar = figure(...
                'Name',             title, ...
                'NumberTitle',      'off', ...
                'Visible',          visible, ...
                'Color',            backgroundColor, ...
                'OuterPosition',    monitorRect(iBigMonitor, :));
            
            hAxMooringVar = axes('Parent', hFigMooringVar);
            
            if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'})), set(hAxMooringVar, 'YDir', 'reverse'); end
            set(get(hAxMooringVar, 'XLabel'), 'String', 'Time');
            yLabel = [varName ' (' varUnit ')'];
            if strcmpi(varName, 'TIME'), yLabel = ['diff ' yLabel]; end
            set(get(hAxMooringVar, 'YLabel'), 'String', yLabel, 'Interpreter', 'none');
            set(get(hAxMooringVar, 'Title'), 'String', title, 'Interpreter', 'none');
            set(hAxMooringVar, 'XTick', (xMin:(xMax-xMin)/4:xMax));
            set(hAxMooringVar, 'XLim', [xMin, xMax]);
            hold(hAxMooringVar, 'on');
            
            % dummy entry for first entry in legend
            hLineVar(1) = plot(0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color same as background (invisible in legend)
            
            % set data cursor mode custom display
            dcm_obj = datacursormode(hFigMooringVar);
            set(dcm_obj, 'UpdateFcn', {@customDcm, sample_data});
            
            % set zoom datetick update
            datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
            zoomH = zoom(hFigMooringVar);
            panH = pan(hFigMooringVar);
            set(zoomH,'ActionPostCallback',{@zoomDateTick, hAxMooringVar});
            set(panH,'ActionPostCallback',{@zoomDateTick, hAxMooringVar});
            
            try
                defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                cMap = colormap(hAxMooringVar, defaultColormapFh(lenSampleData));
            catch e
                cMap = colormap(hAxMooringVar, parula(lenSampleData));
            end
            % reverse the colorbar as we want surface instruments with warmer colors
            cMap = flipud(cMap);
            
            initiateFigure = false;
        end
        
        if strcmpi(varName, 'DEPTH')
            hNominalDepth = line([xMin, xMax], [metaDepth(i), metaDepth(i)], ...
                'Color', 'black');
            % turn off legend entry for this plot
            set(get(get(hNominalDepth,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        end
        
        iGood = true(size(sample_data{iSort(i)}.(typeVar){iVar}.data));
        
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.(typeVar){iVar}.flags;
            
            iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
        end
        
        if all(~iGood) && isQC
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', there is not any ' varName ' data with good flags.']);
            continue;
        else
            isPlottable = true;
            
            xLine = sample_data{iSort(i)}.dimensions{iTime}.data;
            xLine(~iGood) = NaN;
            
            dataVar = sample_data{iSort(i)}.(typeVar){iVar}.data;
            dataVar(~iGood) = NaN;
            
            if strcmpi(varName, 'TIME')
                xLine(1) = [];
                dataVar = diff(dataVar)*24*3600;
            end
            
            hLineVar(i + 1) = line(xLine, dataVar, ...
                'Color', cMap(i, :));
            userData.idx = iSort(i);
            userData.xName = 'TIME';
            if strcmpi(varName, 'TIME')
                userData.yName = 'diff(TIME)';
            else
                userData.yName = varName;
            end
            set(hLineVar(i + 1), 'UserData', userData);
            clear('userData');
            
            % Let's redefine properties after pcolor to make sure grid lines appear
            % above color data and XTick and XTickLabel haven't changed
            set(hAxMooringVar, ...
                'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
                'XGrid',        'on', ...
                'YGrid',        'on', ...
                'Layer',        'top');
            
            % set axes background to be transparent (figure color shows
            % through)
            set(hAxMooringVar, 'Color', 'none')
        end
    end
end

if ~initiateFigure && isPlottable
    if ~isQC
        % we add the in/out water boundaries
        % for global/regional range and in/out water display
        mWh = findobj('Tag', 'mainWindow');
        qcParam = get(mWh, 'UserData');
        yLim = get(hAxMooringVar, 'YLim');
        for i=1:lenSampleData
            iVar = getVar(sample_data{iSort(i)}.(typeVar), varName);
            
            if iVar && isfield(qcParam, 'inWater')
                dataVar = sample_data{iSort(i)}.(typeVar){iVar}.data;
                
                line([qcParam(iSort(i)).inWater, qcParam(iSort(i)).inWater, NaN, qcParam(iSort(i)).outWater, qcParam(iSort(i)).outWater], ...
                    [yLim, NaN, yLim], ...
                    'Parent', hAxMooringVar, ...
                    'Color', 'r', ...
                    'LineStyle', '--');
                
                iTime = getVar(sample_data{i}.dimensions, 'TIME');
                xLine = sample_data{iSort(i)}.dimensions{iTime}.data;
                
                if strcmpi(varName, 'TIME')
                    xLine(1) = [];
                    dataVar = diff(dataVar)*24*3600;
                end
                
                text(qcParam(iSort(i)).inWater, double(dataVar(find(xLine >= qcParam(iSort(i)).inWater, 1, 'first'))), ...
                    ['inWater @ ' datestr(qcParam(iSort(i)).inWater, 'yyyy-mm-dd HH:MM:SS UTC') ' - ' instrumentDesc{i + 1}], ...
                    'Parent', hAxMooringVar);
                text(qcParam(iSort(i)).outWater, double(dataVar(find(xLine <= qcParam(iSort(i)).outWater, 1, 'last'))), ...
                    ['outWater @ ' datestr(qcParam(iSort(i)).outWater, 'yyyy-mm-dd HH:MM:SS UTC') ' - ' instrumentDesc{i + 1}], ...
                    'Parent', hAxMooringVar);
            end
        end
    end
    
    iNan = isnan(hLineVar);
    if any(iNan)
        hLineVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    % Let's add a fake colorbar to have consistent display with or
    % without colorbar
    cb = colorbar('peer', hAxMooringVar);
    set(get(cb, 'YLabel'), 'String', 'TEST');
    pos_with_colorbar = get(hAxMooringVar, 'Position');
    colorbar(cb, 'off');
    set(hAxMooringVar, 'Position', pos_with_colorbar);
    
    datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend, maximum 3 columns
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
    hLegend = legendflex(hAxMooringVar, instrumentDesc,...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols,...
        'FontSize', fontSizeAx,...
        'xscale', xscale);
    posAx = get(hAxMooringVar, 'Position');
    set(hLegend, 'Units', 'Normalized', 'Color', 'none');
    posLh = get(hLegend, 'Position');
    if posLh(2) < 0
        set(hLegend, 'Position',[posLh(1), abs(posLh(2)), posLh(3), posLh(4)]);
        set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+2*abs(posLh(2)), posAx(3), posAx(4)-2*abs(posLh(2))]);
    else
        set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+abs(posLh(2)), posAx(3), posAx(4)-abs(posLh(2))]);
    end
    
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        fastSaveas(hFigMooringVar, backgroundColor, fullfile(exportDir, fileName));
        
        close(hFigMooringVar);
    end
end

%%
    function datacursorText = customDcm(~, event_obj, sample_data)
        %customDatacursorText : custom data tip display
        
        % Display the position of the data cursor
        % obj          Currently not used (empty)
        % event_obj    Handle to event object
        % output_txt   Data cursor text string (string or cell array of strings).
        % event_obj
        % xVarName, yVarName, zVarName : x, y, z (coloured by variable) names,
        
        dataIndex = get(event_obj,'DataIndex');
        posClic = get(event_obj,'Position');
        
        p=get(event_obj,'Target');
        userData = get(p, 'UserData');
        
        xName = userData.xName;
        yName = userData.yName;
        
        if strcmp(yName, 'diff(TIME)'), yName = 'TIME'; end
        
        sam = sample_data{userData.idx};
        
        ixVar = getVar(sam.dimensions, xName);
        if ixVar ~= 0
            xUnits  = sam.dimensions{ixVar}.units;
        else
            % generalized case pass in a variable instead of a dimension
            ixVar = getVar(sam.variables, xName);
            xUnits  = sam.variables{ixVar}.units;
        end
        
        iyVar = getVar(sam.dimensions, yName);
        if iyVar ~= 0
            yUnits  = sam.dimensions{iyVar}.units;
        else
            % generalized case pass in a variable instead of a dimension
            iyVar = getVar(sam.variables, yName);
            yUnits  = sam.variables{iyVar}.units;
        end
        
        if strcmp(xName, 'TIME')
            xStr = datestr(posClic(1),'dd-mm-yyyy HH:MM:SS.FFF');
        else
            xStr = [num2str(posClic(1)) ' ' xUnits];
        end
        
        if strcmp(userData.yName, 'TIME')
            yStr = datestr(posClic(2),'dd-mm-yyyy HH:MM:SS.FFF');
        elseif strcmp(userData.yName, 'diff(TIME)')
            yStr = [num2str(posClic(2)) ' (s)']; %num2str(posClic(2),4)
        else
            yStr = [num2str(posClic(2)) ' (' yUnits ')']; %num2str(posClic(2),4)
        end
        
        datacursorText = {get(p,'DisplayName'),...
            [xName ': ' xStr],...
            [userData.yName ': ' yStr]};
        %datacursorText{end+1} = ['FileName: ',get(p,'Tag')];
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