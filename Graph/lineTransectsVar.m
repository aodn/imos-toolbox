function lineTransectsVar(sample_data, varName, isQC, saveToFile, exportDir)
%LINETRANSECTSVAR Opens a new window where the selected 1D
% variables collected by all the transects are plotted.
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
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated
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
%     * Neither the name of the eMII/IMOS nor the names of its contributors
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
if ~ischar(varName),        error('varName must be a string');          end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

varTitle = imosParameters(varName, 'long_name');
varUnit = imosParameters(varName, 'uom');

stringQC = 'non QC';
if isQC, stringQC = 'QC'; end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

title = [sample_data{1}.vessel_name ' Thermosalinograph ' stringQC '''d good ' varTitle ' before service ' sample_data{1}.meta.deployment.EndFieldTrip];

%sort instruments by deployment alphabetically
lenSampleData = length(sample_data);
deployment = cell(lenSampleData, 1);
xMin = nan(lenSampleData, 1);
xMax = nan(lenSampleData, 1);
yMin = nan(lenSampleData, 1);
yMax = nan(lenSampleData, 1);
for i=1:lenSampleData
    deployment{i} = sample_data{i}.meta.deployment.DeploymentId;
    
    iTime = getVar(sample_data{i}.dimensions, 'TIME');
    iLat = getVar(sample_data{i}.variables, 'LATITUDE');
    iLon = getVar(sample_data{i}.variables, 'LONGITUDE');
    iVar = getVar(sample_data{i}.variables, varName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
    
    % the variable exists, is QC'd and is 1D
    if isQC && iVar && size(sample_data{i}.variables{iVar}.data, 2) == 1
        %get QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        latFlags = sample_data{i}.variables{iLat}.flags;
        lonFlags = sample_data{i}.variables{iLon}.flags;
        varFlags = sample_data{i}.variables{iVar}.flags;
        
        iGood = (timeFlags == 1 | timeFlags == 2) & ...
            (latFlags == 1 | latFlags == 2) & ...
            (lonFlags == 1 | lonFlags == 2) & ...
            (varFlags == 1 | varFlags == 2);
    end
    
    if iVar
        if all(~iGood)
            continue;
        end
        xMin(i) = min(sample_data{i}.variables{iLon}.data(iGood));
        xMax(i) = max(sample_data{i}.variables{iLon}.data(iGood));
        yMin(i) = min(sample_data{i}.variables{iLat}.data(iGood));
        yMax(i) = max(sample_data{i}.variables{iLat}.data(iGood));
    end
end
[deployment, iSort] = sort(deployment);
xMin = min(xMin);
xMax = max(xMax);
yMin = min(yMin);
yMax = max(yMax);
distMin = 0;
distMax = WGS84dist(yMax, xMin, yMin, xMax)/1000; % metre to km

instrumentDesc = cell(lenSampleData + 1, 1);
hLineVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'DeploymentId';
hLineVar(1) = 0;

initiateFigure = true;
isPlottable = false;

backgroundColor = [0.75 0.75 0.75];

for i=1:lenSampleData
    % instrument description
    instrumentDesc{i + 1} = [deployment{i} ' - ' sample_data{i}.meta.transectType];
    
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iLat = getVar(sample_data{i}.variables, 'LATITUDE');
    iLon = getVar(sample_data{i}.variables, 'LONGITUDE');
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 && ... % we're only plotting 1D variables but no current
            all(~strncmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3'}, 4))
        if initiateFigure
            fileName = genIMOSFileName(sample_data{iSort(i)}, 'png');
            visible = 'on';
            if saveToFile, visible = 'off'; end
            hFigTransectsVar = figure(...
                'Name', title, ...
                'NumberTitle','off', ...
                'Visible', visible, ...
                'OuterPosition', monitorRect(iBigMonitor, :));
            
            hAxTransectsVar = axes('Parent',   hFigTransectsVar);
            if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'})), set(hAxTransectsVar, 'YDir', 'reverse'); end
            set(get(hAxTransectsVar, 'XLabel'), 'String', ['Distance in km from max Latitude and min Longitude (' num2str(yMax) ', ' num2str(xMin) ')']);
            set(get(hAxTransectsVar, 'YLabel'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
            set(get(hAxTransectsVar, 'Title'), 'String', title, 'Interpreter', 'none');
            set(hAxTransectsVar, 'XTick', (distMin:(distMax-distMin)/4:distMax));
            set(hAxTransectsVar, 'XLim', [distMin, distMax]);
            hold(hAxTransectsVar, 'on');
            
            % dummy entry for first entry in legend
            hLineVar(1) = plot(0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)
            
            % set data cursor mode custom display
            dcm_obj = datacursormode(hFigTransectsVar);
            set(dcm_obj, 'UpdateFcn', {@customDcm, sample_data});
            
            % set zoom datetick update
            zoomH = zoom(hFigTransectsVar);
            panH = pan(hFigTransectsVar);
            set(zoomH,'ActionPostCallback',{@zoomDistTick, hAxTransectsVar});
            set(panH,'ActionPostCallback',{@zoomDistTick, hAxTransectsVar});
            
            try
                defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                cMap = colormap(hAxTransectsVar, defaultColormapFh(lenSampleData));
            catch e
                cMap = colormap(hAxTransectsVar, parula(lenSampleData));
            end
            % reverse the colorbar as we want surface instruments with warmer colors
            cMap = flipud(cMap);
            
            initiateFigure = false;
        end
        
        if strcmpi(varName, 'DEPTH')
            hNominalDepth = line([distMin, distMax], [sample_data{i}.instrument_nominal_depth, sample_data{i}.instrument_nominal_depth], ...
                'Color', 'black');
            % turn off legend entry for this plot
            set(get(get(hNominalDepth,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        end
        
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        
        if isQC
            %get QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            latFlags = sample_data{i}.variables{iLat}.flags;
            lonFlags = sample_data{i}.variables{iLon}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGood = (timeFlags == 1 | timeFlags == 2) & ...
                (latFlags == 1 | latFlags == 2) & ...
                (lonFlags == 1 | lonFlags == 2) & ...
                (varFlags == 1 | varFlags == 2);
        end
        
        if all(~iGood) && isQC
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', there is not any ' varName ' data with good flags.']);
            continue;
        else
            isPlottable = true;
            
            xLine = WGS84dist(ones(size(iGood))*yMax, ones(size(iGood))*xMin, sample_data{i}.variables{iLat}.data, sample_data{i}.variables{iLon}.data)/1000; % metre to km
            xLine(~iGood) = NaN;
            
            dataVar = sample_data{iSort(i)}.variables{iVar}.data;
            dataVar(~iGood) = NaN;
            
            hLineVar(i + 1) = line(xLine, ...
                dataVar, ...
                'Color', cMap(i, :), ...
                'LineStyle', '-');
            userData.idx = iSort(i);
            userData.xName = 'DISTANCE';
            userData.yName = varName;
            set(hLineVar(i + 1), 'UserData', userData);
            clear('userData');
            % Let's redefine properties after pcolor to make sure grid lines appear
            % above color data and XTick and XTickLabel haven't changed
            set(hAxTransectsVar, ...
                'XTick',        (distMin:(distMax-distMin)/4:distMax), ...
                'XGrid',        'on', ...
                'YGrid',        'on', ...
                'Layer',        'top');
            
            % set background to be grey
            set(hAxTransectsVar, 'Color', backgroundColor)
        end
    end
end

if ~initiateFigure && isPlottable
    iNan = isnan(hLineVar);
    if any(iNan)
        hLineVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    % Let's add a fake colorbar to have consistent display with or
    % without colorbar
    cb = colorbar('peer', hAxTransectsVar);
    set(get(cb, 'YLabel'), 'String', 'TEST');
    pos_with_colorbar = get(hAxTransectsVar, 'Position');
    colorbar(cb, 'off');
    set(hAxTransectsVar, 'Position', pos_with_colorbar);
    
    % we try to split the legend, maximum 9 columns
    fontSizeAx = get(hAxTransectsVar,'FontSize');
    fontSizeLb = get(get(hAxTransectsVar,'XLabel'),'FontSize');
    xscale = 0.9;
    nCols = ceil(numel(instrumentDesc)/4);
    if nCols > 9
        nCols = 9;
    end
    
    hYBuffer = 1.1 * (2*(fontSizeAx + fontSizeLb));
    hLegend = legendflex(hAxTransectsVar, instrumentDesc,...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols,...
        'FontSize', fontSizeAx,...
        'xscale',xscale);
    posAx = get(hAxTransectsVar, 'Position');
    set(hLegend, 'Units', 'Normalized', 'color', backgroundColor);
    posLh = get(hLegend, 'Position');
    if posLh(2) < 0
        set(hLegend, 'Position',[posLh(1), abs(posLh(2)), posLh(3), posLh(4)]);
        set(hAxTransectsVar, 'Position',[posAx(1), posAx(2)+2*abs(posLh(2)), posAx(3), posAx(4)-2*abs(posLh(2))]);
    else
        set(hAxTransectsVar, 'Position',[posAx(1), posAx(2)+abs(posLh(2)), posAx(3), posAx(4)-abs(posLh(2))]);
    end
    
    if saveToFile
        % ensure the printed version is the same whatever the screen used.
        set(hFigTransectsVar, 'PaperPositionMode', 'manual');
        set(hFigTransectsVar, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
        
        % preserve the color scheme
        set(hFigTransectsVar, 'InvertHardcopy', 'off');
        
        fileName = strrep(fileName, '_PARAM.', ['_', varName, '.']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        % use hardcopy as a trick to go faster than print.
        % opengl (hardware or software) should be supported by any platform and go at least just as
        % fast as zbuffer. With hardware accelaration supported, could even go a
        % lot faster.
        imwrite(hardcopy(hFigTransectsVar, '-dopengl'), fullfile(exportDir, fileName), 'png');
        close(hFigTransectsVar);
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
        
        sam = sample_data{userData.idx};
        
        ixVar = getVar(sam.variables, xName);
        if ixVar ~= 0
            xUnits  = sam.dimensions{ixVar}.units;
        else
            xUnits = 'km';
        end
        
        iyVar = getVar(sam.variables, yName);
        yUnits  = sam.variables{iyVar}.units;
        
        xStr = [num2str(posClic(1)) ' (' xUnits ')'];
        yStr = [num2str(posClic(2)) ' (' yUnits ')'];
        
        datacursorText = {get(p,'DisplayName'),...
            [xName ': ' xStr],...
            [yName ': ' yStr]};

    end

%%
    function zoomDistTick(obj,event_obj,hAx)
        xLim = get(hAx, 'XLim');
        currXTicks = get(hAx, 'xtick');
        newXTicks = linspace(xLim(1), xLim(2), length(currXTicks));
        set(hAx, 'xtick', newXTicks);

    end

end