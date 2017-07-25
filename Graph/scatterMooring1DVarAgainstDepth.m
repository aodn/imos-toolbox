function scatterMooring1DVarAgainstDepth(sample_data, varName, isQC, saveToFile, exportDir)
%SCATTERMOORING1DVARAGAINSTDEPTH Opens a new window where the selected
% variable collected by all the intruments on the mooring are plotted.
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
if ~ischar(varName),        error('varName must be a string');          end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'})), return; end

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
    izVar = getVar(sample_data{i}.variables, varName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
    
    % the variable exists, is QC'd and is 1D
    if isQC && izVar && size(sample_data{i}.variables{izVar}.data, 2) == 1
        %get time and var QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        varFlags = sample_data{i}.variables{izVar}.flags;
        
        iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
    end
    
    if izVar
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
hScatterVar(1) = line(0, 0, 'Visible', 'off', 'LineStyle', 'none', 'Marker', 'none');

% we need to go through every instruments to figure out the CLim properties
% on which the subset plots happen below.
minClim = NaN;
maxClim = NaN;
isPlottable = false(1, lenSampleData);
for i=1:lenSampleData
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
    izVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if izVar > 0 && size(sample_data{iSort(i)}.variables{izVar}.data, 2) == 1 && ... % we're only plotting 1D variables with depth variable but no current
            all(~strncmpi(sample_data{iSort(i)}.variables{izVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3'}, 4))
        iGood = true(size(sample_data{iSort(i)}.variables{izVar}.data));
        if isQC
            %get time, depth and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{izVar}.flags;
            
            iGood = ismember(timeFlags, goodFlags) & ismember(varFlags, goodFlags);
            
            if iDepth
                depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                iGood = iGood & ismember(depthFlags, goodFlags);
            end
        end
        
        if any(iGood)
            isPlottable(i) = true;
            minClim = min(minClim, min(sample_data{iSort(i)}.variables{izVar}.data(iGood)));
            maxClim = max(maxClim, max(sample_data{iSort(i)}.variables{izVar}.data(iGood)));
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
        iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
        izVar = getVar(sample_data{iSort(i)}.variables, varName);
        
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
                
                hAxMooringVar = axes('Parent',   hFigMooringVar);
            
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
                
                try
                    nColors = str2double(readProperty('visualQC.ncolors'));
                    defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                    cMap = colormap(hAxMooringVar, defaultColormapFh(nColors));
                catch e
                    nColors = 64;
                    cMap = colormap(hAxMooringVar, parula(nColors));
                end
                
                hCBar = colorbar('peer', hAxMooringVar);
                set(get(hCBar, 'Title'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
                
                initiateFigure = false;
            end
            
            iGood = true(size(sample_data{iSort(i)}.variables{izVar}.data));
            iGoodDepth = iGood;
            
            if isQC
                %get time, depth and var QC information
                timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
                varFlags = sample_data{iSort(i)}.variables{izVar}.flags;
                varValues = sample_data{iSort(i)}.variables{izVar}.data;
                
                iGood = ismember(timeFlags, goodFlags) & ...
                    ismember(varFlags, goodFlags) & ...
                    ~isnan(varValues);
                
                if iDepth
                    depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                    iGoodDepth = ismember(depthFlags, goodFlags);
                end
            end
            
            if all(~iGood) && isQC
                fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                    ', there is not any ' varName ' data with good flags.']);
                continue;
            else
                if iDepth
                    depth = sample_data{iSort(i)}.variables{iDepth}.data;
                else
                    if isfield(sample_data{iSort(i)}, 'instrument_nominal_depth')
                        if ~isempty(sample_data{iSort(i)}.instrument_nominal_depth)
                            depth = sample_data{iSort(i)}.instrument_nominal_depth*ones(size(iGood));
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
                depth(~iGoodDepth) = metaDepth(i);
                depth = depth(iGood);
                
                % data for customDcm
                userData.idx = iSort(i);
                userData.xName = 'TIME';
                userData.yName = 'DEPTH';
                userData.zName = varName;
                userData.iGood = iGood;
                
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
                        sample_data{iSort(i)}.dimensions{iTime}.data(iGood), ...
                        depth, ...
                        sample_data{iSort(i)}.variables{izVar}.data(iGood), ...
                        markerStyle{mod(i, lenMarkerStyle)+1}, ...
                        [minClim maxClim], ...
                        'DisplayName', instrumentDesc{i+1}, ...
                        'MarkerSize',  2.5, ...
                        'UserData',    userData);
                else
                    % faster than scatter, but legend requires adjusting
                    h = fastScatterMesh( hAxMooringVar, ...
                        sample_data{iSort(i)}.dimensions{iTime}.data(iGood), ...
                        depth, ...
                        sample_data{iSort(i)}.variables{izVar}.data(iGood), ...
                        [minClim maxClim], ...
                        'Marker',      markerStyle{mod(i, lenMarkerStyle)+1}, ...
                        'DisplayName', [markerStyle{mod(i, lenMarkerStyle)+1} ' ' instrumentDesc{i+1}], ...
                        'MarkerSize',  2.5, ...
                        'UserData',    userData);
                end
                clear('userData');                
                
                if ~isempty(h), hScatterVar(i + 1) = h; end
                
                % Let's redefine properties after pcolor to make sure grid lines appear
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

% we need to reset the CLim to a global range rather than the one for the
% last subset of plot
set(hAxMooringVar, 'CLim', [minClim maxClim]);

if ~initiateFigure
    iNan = isnan(hScatterVar);
    if any(iNan)
        hScatterVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend in two location horizontally
    nLine = length(hScatterVar);
    fontSizeAx = get(hAxMooringVar,'FontSize');
    fontSizeLb = get(get(hAxMooringVar,'XLabel'),'FontSize');
    xscale = 0.9;
    if nLine > 2
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
        hLegend = legendflex(hAxMooringVar, instrumentDesc, ...
            'anchor', [6 2], ...
            'buffer', [0 -hYBuffer], ...
            'ncol', nCols,...
            'FontSize', fontSizeAx, ...
            'xscale', xscale);
        entries = get(hLegend,'children');
        % if used mesh for scatter plot then have to clean up legend
        % entries
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
        set(hLegend, 'Units', 'Normalized', 'color', backgroundColor);
        posLh = get(hLegend, 'Position');
        if posLh(2) < 0
            set(hLegend, 'Position',[posLh(1), abs(posLh(2)), posLh(3), posLh(4)]);
            set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+2*abs(posLh(2)), posAx(3), posAx(4)-2*abs(posLh(2))]);
        else
            set(hAxMooringVar, 'Position',[posAx(1), posAx(2)+abs(posLh(2)), posAx(3), posAx(4)-abs(posLh(2))]);
        end
    else
        % doesn't make sense to continue and export to file since seing a
        % scatter plot in depth only helps to analyse the data in its
        % context that is to say with nearest similar datasets.
        close(hFigMooringVar);
        return;
    end
    
    % set(hLegend, 'Box', 'off', 'Color', 'none');
    
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_SCATTER_');
        
        fastSaveas(hFigMooringVar, fullfile(exportDir, fileName));
        
        close(hFigMooringVar);
    end
end

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
                zData = sam.dimensions{izVar}.data(userData.iGood);
            else
                izVar = getVar(sam.variables, zName);
                zUnits  = sam.variables{izVar}.units;
                zData = sam.variables{izVar}.data(userData.iGood);
            end
            iTime = getVar(sam.dimensions, 'TIME');
            timeData = sam.dimensions{iTime}.data(userData.iGood);
            idx = find(abs(timeData-posClic(1))<eps(10));
            if strcmp(zName, 'TIME')
                zStr = datestr(zData(idx),'dd-mm-yyyy HH:MM:SS.FFF');
            else
                zStr = [num2str(zData(idx)) ' (' zUnits ')'];
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