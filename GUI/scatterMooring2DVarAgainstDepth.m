function scatterMooring2DVarAgainstDepth(sample_data, varName, isQC, saveToFile, exportDir)
%SCATTERMOORING2DVARAGAINSTDEPTH Opens a new window where the selected 2D
% variables collected by all the intruments on the mooring are plotted.
%

varTitle = imosParameters(varName, 'long_name');
varUnit = imosParameters(varName, 'uom');

if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'}))
    return;
end

stringQC = 'non QC';
if isQC, stringQC = 'QC'; end

%plot depth information
monitorRec = get(0,'MonitorPosition');
xResolution = monitorRec(:, 3)-monitorRec(:, 1);
iBigMonitor = xResolution == max(xResolution);
if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors
title = [sample_data{1}.deployment_code ' mooring''s instruments ' stringQC '''d good ' varTitle];

%sort instruments by depth
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
    xMin = min(sample_data{i}.dimensions{iTime}.data);
    xMax = max(sample_data{i}.dimensions{iTime}.data);
end
[metaDepth, iSort] = sort(metaDepth);
xMin = min(xMin);
xMax = max(xMax);

markerStyle = {'+', 'o', '*', '.', 'x', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
lenMarkerStyle = length(markerStyle);

instrumentDesc = cell(lenSampleData + 1, 1);
hScatterVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'Make Model (nominal depth - instrument SN)';
hScatterVar(1) = 0;

% we need to go through every instruments to figure out the CLim properties
% on which the subset plots happen below.
yLimMin = NaN;
yLimMax = NaN;
isPlotable = false(1, lenSampleData);
for i=1:lenSampleData
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iHeight = getVar(sample_data{iSort(i)}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && iHeight > 0 && iDepth > 0 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) > 1 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 3) == 1 % we're plotting ADCP 2D variables with DEPTH variable.
        isPlotable(i) = true;
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGoodDepth = (depthFlags == 1 | depthFlags == 2);
            iGoodTime = (timeFlags == 1 | timeFlags == 2) & iGoodDepth; % bad depth <=> bad time
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & (varFlags == 1 | varFlags == 2) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
        end
        
        if any(any(iGood))
            yLimMin = min(yLimMin, min(min(sample_data{iSort(i)}.variables{iVar}.data(iGood))));
            yLimMax = max(yLimMax, max(max(sample_data{iSort(i)}.variables{iVar}.data(iGood))));
        end
        
    elseif iVar > 0 && iDepth > 0 && ...
            any(strcmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD'})) && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 % we're plotting current metre 1D variables with DEPTH variable.
        isPlotable(i) = true;
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGoodDepth = (depthFlags == 1 | depthFlags == 2);
            iGoodTime = (timeFlags == 1 | timeFlags == 2) & iGoodDepth; % bad depth <=> bad time
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & (varFlags == 1 | varFlags == 2) & ~isnan(sample_data{iSort(i)}.variables{iVar}.data);
        end
        
        if any(any(iGood))
            yLimMin = min(yLimMin, min(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
            yLimMax = max(yLimMax, max(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
        end
    end
end

if any(isPlotable)
    % collect visualQC config
    try
        fastScatter = eval(readProperty('visualQC.fastScatter'));
    catch e %#ok<NASGU>
        fastScatter = true;
    end
    
    % define cMap, cLim and cType per parameter
    switch varName
        case {'UCUR', 'VCUR', 'WCUR'}   % 0 centred parameters
            cMap = 'r_b';
            cType = 'centeredOnZero';
            CLim = [-yLimMax yLimMax];
        case {'CDIR', 'SSWD'}           % directions [0; 360[
            cMap = 'rkbwr';
            cType = 'direction';
            CLim = [0 360];
        case {'CSPD'}                   % [0; oo[ paremeters
            cMap = 'jet';
            cType = 'positiveFromZero';
            CLim = [0 yLimMax];
        otherwise
            cMap = 'jet';
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
        iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
        iVar = getVar(sample_data{iSort(i)}.variables, varName);
        
        if isPlotable(i)
            if initiateFigure
                fileName = genIMOSFileName(sample_data{iSort(i)}, 'png');
                visible = 'on';
                if saveToFile, visible = 'off'; end
                hFigMooringVar = figure(...
                    'Name', title, ...
                    'NumberTitle', 'off', ...
                    'Visible', visible, ...
                    'OuterPosition', [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);
                
                hAxMooringVar = axes('Parent',   hFigMooringVar);
                set(hAxMooringVar, 'YDir', 'reverse');
                set(get(hAxMooringVar, 'XLabel'), 'String', 'Time');
                set(get(hAxMooringVar, 'YLabel'), 'String', 'DEPTH (m)', 'Interpreter', 'none');
                set(get(hAxMooringVar, 'Title'), 'String', title, 'Interpreter', 'none');
                set(hAxMooringVar, 'XTick', (xMin:(xMax-xMin)/4:xMax));
                set(hAxMooringVar, 'XLim', [xMin, xMax]);
                hold(hAxMooringVar, 'on');
                
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
            
            if isQC
                %get time and var QC information
                timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
                depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
                varValues = sample_data{iSort(i)}.variables{iVar}.data;
                
                iGoodDepth = (depthFlags == 1 | depthFlags == 2);
                iGoodTime = (timeFlags == 1 | timeFlags == 2) & iGoodDepth; % bad depth <=> bad time
                
                iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
                iGood = iGood & (varFlags == 1 | varFlags == 2) & ~isnan(varValues);
            end
            
            iGoodHeight = any(iGood, 1);
            nGoodHeight = sum(iGoodHeight);
%             nGoodHeight = nGoodHeight + 1;
%             iGoodHeight(nGoodHeight) = 1;
            
            if all(all(~iGood)) && isQC
                fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                    ', there is not any ' varName ' data with good flags.']);
            else
                xScatter = sample_data{iSort(i)}.dimensions{iTime}.data;
                xScatter(~iGoodTime) = NaN;
                
                if iHeight > 0
                    yScatter = sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight);
                else
                    yScatter = 0;
                end
                
                dataDepth = sample_data{iSort(i)}.variables{iDepth}.data;
                dataDepth(~iGoodTime) = NaN;
                
                dataVar = sample_data{iSort(i)}.variables{iVar}.data;
                dataVar(~iGood) = NaN;
                
                for j=1:nGoodHeight
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
                            CLim);
                    else
                        h = scatter(hAxMooringVar, ...
                            xScatter, ...
                            dataDepth - yScatter(j), ...
                            5, ...
                            dataVar(:, j), ...
                            markerStyle{mod(i, lenMarkerStyle)+1}, ...
                            MarkerFaceColor, 'none');
                    end
                    
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
                set(hAxMooringVar, 'Color', [0.75 0.75 0.75])
            end
            
            % we plot the instrument nominal depth
            hScatterVar(1) = line([xMin, xMax], [metaDepth(i), metaDepth(i)], ...
                'Color', 'black');
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
    
    % we try to split the legend in two location horizontally
    nLine = length(hScatterVar);
    if nLine > 2
        nLine1 = ceil(nLine/2);
        
        hLegend(1) = multipleLegend(hAxMooringVar, hScatterVar(1:nLine1),         instrumentDesc(1:nLine1),       'Location', 'SouthOutside');
        hLegend(2) = multipleLegend(hAxMooringVar, hScatterVar(nLine1+1:nLine),   instrumentDesc(nLine1+1:nLine), 'Location', 'SouthOutside');
        
        posAx = get(hAxMooringVar, 'Position');
        
        pos1 = get(hLegend(1), 'Position');
        pos2 = get(hLegend(2), 'Position');
        maxWidth = max(pos1(3), pos2(3));

        set(hLegend(1), 'Position', [0   + 2*maxWidth, pos1(2), pos1(3), pos1(4)]);
        set(hLegend(2), 'Position', [0.5 + 2*maxWidth, pos1(2), pos1(3), pos1(4)]);
        
        % set position on legends above modifies position of axis so we
        % re-initialise it
        set(hAxMooringVar, 'Position', posAx);
    else
        hLegend = legend(hAxMooringVar, hScatterVar, instrumentDesc, 'Location', 'SouthOutside');
        
        % unfortunately we need to do this hack so that we have consistency with
        % the case above
        posAx = get(hAxMooringVar, 'Position');
        set(hAxMooringVar, 'Position', posAx);
    end
    
%     set(hLegend, 'Box', 'off', 'Color', 'none');
    
    if saveToFile
        % ensure the printed version is the same whatever the screen used.
        set(hFigMooringVar, 'PaperPositionMode', 'manual');
        set(hFigMooringVar, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
        
        % preserve the color scheme
        set(hFigMooringVar, 'InvertHardcopy', 'off');
                    
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_SCATTER_');
        
        % use hardcopy as a trick to go faster than print.
        % opengl (hardware or software) should be supported by any platform and go at least just as
        % fast as zbuffer. With hardware accelaration supported, could even go a
        % lot faster.
        imwrite(hardcopy(hFigMooringVar, '-dopengl'), fullfile(exportDir, fileName), 'png');
        close(hFigMooringVar);
    end
end

end