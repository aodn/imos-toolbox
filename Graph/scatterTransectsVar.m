function scatterTransectsVar(sample_data, varName, isQC, saveToFile, exportDir)
%SCATTERTRANSECTSVAR Opens a new window where the selected 1D
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
varData = [];
for i=1:lenSampleData
    deployment{i} = sample_data{i}.meta.deployment.DeploymentId;
    
    iTime = getVar(sample_data{i}.dimensions, 'TIME');
    iLat = getVar(sample_data{i}.variables, 'LATITUDE');
    iLon = getVar(sample_data{i}.variables, 'LONGITUDE');
    iVar = getVar(sample_data{i}.variables, varName);
    
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
    else
        time = sample_data{i}.dimensions{iTime}.data;
        lat = sample_data{i}.variables{iLat}.data;
        lon = sample_data{i}.variables{iLon}.data;
        
        iGood = ~isnan(time) & ...
            ~isnan(lat) & ...
            ~isnan(lon);
        
        if iVar && size(sample_data{i}.variables{iVar}.data, 2) == 1
            var = sample_data{i}.variables{iVar}.data;
            
            iGood = iGood & ...
                ~isnan(var);
        end
    end
    
    if iVar
        if all(~iGood)
            continue;
        end
        
        varData = [varData; sample_data{i}.variables{iVar}.data(iGood)];
    end
end
[deployment, iSort] = sort(deployment);

% we define CLim in order to enhance the contrast when
% visualising data
meanData = mean(varData);
stdDev = std(varData);
clear varData;
CLim = [meanData - 2*stdDev, meanData + 2*stdDev];

instrumentDesc = cell(lenSampleData + 1, 1);
hScatterVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'DeploymentId';
hScatterVar(1) = 0;

initiateFigure = true;
isPlottable = false;

backgroundColor = [0.75 0.75 0.75];
for i=1:lenSampleData
    % instrument description
    instrumentDesc{i + 1} = [deployment{i} ' - ' sample_data{iSort(i)}.meta.transectType];
    
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iLat = getVar(sample_data{iSort(i)}.variables, 'LATITUDE');
    iLon = getVar(sample_data{iSort(i)}.variables, 'LONGITUDE');
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
            set(get(hAxTransectsVar, 'XLabel'), 'String', 'Longitude - Time');
            set(get(hAxTransectsVar, 'YLabel'), 'String', 'Latitude');
            set(get(hAxTransectsVar, 'Title'), 'String', title, 'Interpreter', 'none');
            hold(hAxTransectsVar, 'on');
            
            % dummy entry for first entry in legend
            hScatterVar(1) = plot(0, 0, 'Color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)
            
            % set data cursor mode custom display
            dcm_obj = datacursormode(hFigTransectsVar);
            set(dcm_obj, 'UpdateFcn', {@customDcm, sample_data});
            
            % set zoom axis tick update
            zoomH = zoom(hFigTransectsVar);
            panH = pan(hFigTransectsVar);
            set(zoomH,'ActionPostCallback',{@zoomDistTick, hAxTransectsVar});
            set(panH,'ActionPostCallback',{@zoomDistTick, hAxTransectsVar});
            
            try
                nColors = str2double(readProperty('visualQC.ncolors'));
                defaultColormapFh = str2func(readProperty('visualQC.defaultColormap'));
                cMap = colormap(hAxTransectsVar, defaultColormapFh(nColors));
            catch e
                nColors = 64;
                cMap = colormap(hAxTransectsVar, parula(nColors));
            end
            
            hCBar = colorbar('peer', hAxTransectsVar);
            set(get(hCBar, 'Title'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
            
            initiateFigure = false;
        end
        
        if strcmpi(varName, 'DEPTH')
            hNominalDepth = line([distMin, distMax], ...
                [sample_data{iSort(i)}.instrument_nominal_depth, sample_data{iSort(i)}.instrument_nominal_depth], ...
                'Color', 'black');
            % turn off legend entry for this plot
            set(get(get(hNominalDepth, 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');
        end
        
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        
        if isQC
            %get QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            latFlags = sample_data{iSort(i)}.variables{iLat}.flags;
            lonFlags = sample_data{iSort(i)}.variables{iLon}.flags;
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
            
            tData = sample_data{iSort(i)}.dimensions{iTime}.data;
            if i == 1, tDataFirstTransect = tData; end
            
            xData = sample_data{iSort(i)}.variables{iLon}.data;
            yData = sample_data{iSort(i)}.variables{iLat}.data;
            varData = sample_data{iSort(i)}.variables{iVar}.data;
            varData(~iGood) = NaN;
            
            % each transect is plotted next to each other, a shift of 0.3 degrees in
            % longitude per day occurs for each new transect
            lonShiftPerDay = 0.3;
            xData = xData + lonShiftPerDay*(tData - tDataFirstTransect(end));
%             hScatterVar(i + 1) = scatter(hAxTransectsVar, xData + (i-1)*lonShiftPerDay, yData, [], ...
%                 varData, ...
%                 'filled');
            hScatterVar(i + 1) = plotclr(hAxTransectsVar, ...
                        xData, ...
                        yData, ...
                        varData, ...
                        'o', ...
                        CLim, ...
                        'MarkerSize', sqrt(5));
            
            userData.idx = iSort(i);
            userData.varName = varName;
            set(hScatterVar(i + 1), 'UserData', userData);
            clear('userData');
            
            % we add the transect start date on the plot
            dateStr = datestr(datenum(sample_data{iSort(i)}.meta.deployment.DeploymentId, 'yyyymmddHHMMSS'));
            if strcmpi(sample_data{iSort(i)}.meta.transectType, 'M2D') 
                dir = '<-';
                transLabel = [dir dateStr];
                vAlign = 'Bottom';
                hAlign = 'Left';
                [yPos, iYPos] = max(yData);
            else
                dir = '->';
                transLabel = [dateStr dir];
                vAlign = 'Top';
                hAlign = 'Right';
                [yPos, iYPos] = min(yData);
            end
            
            xPos = xData(iYPos);
            
            hText = text(xPos, yPos, ...
                transLabel, ...
                'VerticalAlignment', vAlign, ...
                'HorizontalAlignment', hAlign);
            set(hText, 'Rotation', 30);
        end
    end
end

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(hAxTransectsVar, ...
    'XGrid',        'on', ...
    'XTick',        [], ...
    'YGrid',        'on', ...
    'Layer',        'top', ...
    'CLim',         CLim);

% set background to be grey
set(hAxTransectsVar, 'Color', backgroundColor)

if ~initiateFigure && isPlottable
    iNan = isnan(hScatterVar);
    if any(iNan)
        hScatterVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    if saveToFile
        % ensure the printed version is the same whatever the screen used.
        set(hFigTransectsVar, 'PaperPositionMode', 'manual');
        set(hFigTransectsVar, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
        
        % preserve the color scheme
        set(hFigTransectsVar, 'InvertHardcopy', 'off');
        
        fileName = strrep(fileName, '_PARAM.', ['_', varName, '.']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_SCATTER_');
        
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
        
        tName = 'TIME';
        xName = 'LONGITUDE';
        yName = 'LATITUDE';
        varName = userData.varName;
        
        sam = sample_data{userData.idx};
        
        iT = getVar(sam.dimensions, tName);
        iX = getVar(sam.variables, xName);
        iY = getVar(sam.variables, yName);
        iVar = getVar(sam.variables, varName);
        
        xUnits  = sam.variables{iX}.units;
        yUnits  = sam.variables{iY}.units;
        varUnits  = sam.variables{iVar}.units;
        
        tStr = datestr(sam.dimensions{iT}.data(dataIndex));
        xStr = [num2str(posClic(1) - 0.3) ' (' xUnits ')'];
        yStr = [num2str(posClic(2)) ' (' yUnits ')'];
        varStr = [num2str(sam.variables{iVar}.data(dataIndex)) ' (' varUnits ')'];
        
        datacursorText = {['Transect start date: ' datestr(datenum(sam.meta.deployment.DeploymentId, 'yyyymmddHHMMSS'))], ...
            ['Transect type: ' sam.meta.transectType], ...
            [tName ': ' tStr], ...
            [xName ': ' xStr], ...
            [yName ': ' yStr], ...
            [varName ': ' varStr]};

    end

%%
    function zoomDistTick(obj,event_obj,hAx)
        yLim = get(hAx, 'YLim');
        

    end

end