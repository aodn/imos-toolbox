function lineCastVar(sample_data, varNames, isQC, saveToFile, exportDir)
%LINECASTVAR Opens a new window where the selected
% variables collected by the CTD are plotted.
%

% we get rid of specific parameters
notNeededParams = {'TIME', 'DIRECTION', 'LATITUDE', 'LONGITUDE', 'BOT_DEPTH', 'PRES', 'PRES_REL', 'DEPTH'};
for i=1:length(notNeededParams)
    iNotNeeded = strcmpi(varNames, notNeededParams{i});
    varNames(iNotNeeded) = [];
end

%plot depth information
monitorRec = get(0,'MonitorPosition');
xResolution = monitorRec(:, 3)-monitorRec(:, 1);
iBigMonitor = xResolution == max(xResolution);
if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors

lineStyle = {'-', '--', ':', '-.'};
lenLineStyle = length(lineStyle);

initiateFigure = true;

lenVarNames = length(varNames);
for k=1:lenVarNames
    varName = varNames{k};
    
    varTitle = imosParameters(varName, 'long_name');
    varUnit = imosParameters(varName, 'uom');
    
    platform = sample_data{1}.platform_code;
    
    lenSampleData = length(sample_data);
    yMin = nan(lenSampleData, 1);
    yMax = nan(lenSampleData, 1);
    for i=1:lenSampleData
        iDepth = getVar(sample_data{i}.dimensions, 'DEPTH');
        yMin(i) = min(sample_data{i}.dimensions{iDepth}.data);
        yMax(i) = max(sample_data{i}.dimensions{iDepth}.data);
    end
    yMin = min(yMin);
    yMax = max(yMax);
    
    instrumentDesc = cell(lenSampleData + 1, 1);
    hLineVar = nan(lenSampleData + 1, 1);
    
    instrumentDesc{1} = 'Make Model (platform - cast date - instrument SN)';
    hLineVar(1) = 0;
    
    for i=1:lenSampleData
        % instrument description
        if ~isempty(strtrim(sample_data{i}.instrument))
            instrumentDesc{i + 1} = sample_data{i}.instrument;
        elseif ~isempty(sample_data{i}.toolbox_input_file)
            [~, instrumentDesc{i + 1}] = fileparts(sample_data{i}.toolbox_input_file);
        end
        
        instrumentSN = '';
        if ~isempty(strtrim(sample_data{i}.instrument_serial_number))
            instrumentSN = sample_data{i}.instrument_serial_number;
        end
        
        instrumentDesc{i + 1} = [strrep(instrumentDesc{i + 1}, '_', ' ') ' (' platform ' - ' datestr(sample_data{i}.time_coverage_start, 'yyyy-mm-dd HH:MM') ' - ' instrumentSN ')'];
        
        %look for depth and relevant variable
        iDepth = getVar(sample_data{i}.dimensions, 'DEPTH');
        iVar = getVar(sample_data{i}.variables, varName);
        
        if iVar > 0
            if initiateFigure
                fileName = genIMOSFileName(sample_data{i}, 'png');
                visible = 'on';
                if saveToFile, visible = 'off'; end
                hFigCastVar = figure(...
                    'Name', 'CTD cast visual QC', ...
                    'NumberTitle','off', ...
                    'Visible', visible, ...
                    'OuterPosition', [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);
                
                initiateFigure = false;
            end
                       
            if i==1
                hAxCastVar = subplot(1, lenVarNames, k);
                set(hAxCastVar, 'YDir', 'reverse');
%                 set(get(hAxCastVar, 'Title'), 'String', varName, 'Interpreter', 'none');
                set(get(hAxCastVar, 'XLabel'), 'String', varName, 'Interpreter', 'none');
%                 if mod(k, 2) == 0 % even
%                     set(get(hAxCastVar, 'XLabel'), 'String', [varTitle ' (' varUnit ')'], 'Interpreter', 'none');
%                 else % odd
%                     % we introduce an empty line to make sure we avoid
%                     % overlapping between xLabels.
%                     set(get(hAxCastVar, 'XLabel'), 'String', {''; [varTitle ' (' varUnit ')']}, 'Interpreter', 'none');
%                 end
                
                if k==1
                    set(get(hAxCastVar, 'YLabel'), 'String', 'Depth (m)');
                end
                set(hAxCastVar, 'YLim', [yMin, yMax]);
                hold(hAxCastVar, 'on');
                
                cMap = colormap(hAxCastVar, jet(lenSampleData));
                cMap = flipud(cMap);
            end
            
            yLine = sample_data{i}.dimensions{iDepth}.data;
            dataVar = sample_data{i}.variables{iVar}.data;
            
            hLineVar(i + 1) = line(dataVar, ...
                yLine, ...
                'Color', cMap(i, :), ...
                'LineStyle', lineStyle{mod(i, lenLineStyle)+1});
            
            xLim = get(hAxCastVar, 'XLim');
            yLim = get(hAxCastVar, 'YLim');
            
            text('String', [' ' varTitle ' (' varUnit ')'], ...
                'Position', [xLim(2), yLim(2)], ...
                'Rotation', 90, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'top', ...
                'Interpreter', 'none')
            
            %get var QC information
            varFlags = sample_data{i}.variables{iVar}.flags;
            
            qcSet = str2double(readProperty('toolbox.qc_set'));
            
            flagGood    = imosQCFlag('good',        qcSet, 'flag');
            flagPGood   = imosQCFlag('probablyGood',qcSet, 'flag');
            flagPBad    = imosQCFlag('probablyBad', qcSet, 'flag');
            flagBad     = imosQCFlag('bad',         qcSet, 'flag');
            
            iGood           = varFlags == flagGood;
            iProbablyGood   = varFlags == flagPGood;
            iProbablyBad    = varFlags == flagPBad;
            iBad            = varFlags == flagBad;
            
            if all(~iGood & ~iProbablyGood) && isQC
                fprintf('%s\n', ['Warning : in ' sample_data{i}.toolbox_input_file ...
                    ', there is not any ' varName ' data with good flags.']);
            end
            
            if any(iGood)
                fc = imosQCFlag(flagGood, qcSet, 'color');
                line(dataVar(iGood), ...
                    yLine(iGood), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            if any(iProbablyGood)
                fc = imosQCFlag(flagPGood, qcSet, 'color');
                line(dataVar(iProbablyGood), ...
                    yLine(iProbablyGood), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            if any(iProbablyBad)
                fc = imosQCFlag(flagPBad, qcSet, 'color');
                line(dataVar(iProbablyBad), ...
                    yLine(iProbablyBad), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            if any(iBad)
                fc = imosQCFlag(flagBad, qcSet, 'color');
                line(dataVar(iBad), ...
                    yLine(iBad), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            % Let's redefine properties after line to make sure grid lines appear
            % above color data and XTick and XTickLabel haven't changed
            set(hAxCastVar, ...
                'XGrid',        'on', ...
                'YGrid',        'on', ...
                'Layer',        'top');
            
            % set background to be grey
            set(hAxCastVar, 'Color', [0.75 0.75 0.75])
        end
    end
    
    if ~initiateFigure
        iNan = isnan(hLineVar);
        if any(iNan)
            hLineVar(iNan) = [];
            instrumentDesc(iNan) = [];
        end
        
        hLegend = legend(hAxCastVar, hLineVar, instrumentDesc, 'Location', 'NorthOutside');
        
        %     set(hLegend, 'Box', 'off', 'Color', 'none');
        if k <= lenVarNames/2 || k > lenVarNames/2 + 1
            set(hLegend, 'Visible', 'off');
        end
    end
    
end
    
if saveToFile
    % ensure the printed version is the same whatever the screen used.
    set(hFigCastVar, 'PaperPositionMode', 'manual');
    set(hFigCastVar, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
    
    % preserve the color scheme
    set(hFigCastVar, 'InvertHardcopy', 'off');
    
    fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_'); % IMOS_[sub-facility_code]_[platform_code]_FV01_[time_coverage_start]_[PLOT-TYPE]_C-[creation_date].png
    
    % use hardcopy as a trick to go faster than print.
    % opengl (hardware or software) should be supported by any platform and go at least just as
    % fast as zbuffer. With hardware accelaration supported, could even go a
    % lot faster.
    imwrite(hardcopy(hFigCastVar, '-dopengl'), fullfile(exportDir, fileName), 'png');
    
    close(hFigCastVar);
end

end