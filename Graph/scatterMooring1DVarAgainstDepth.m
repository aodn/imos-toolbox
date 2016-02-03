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

if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'})), return; end

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
    iVar = getVar(sample_data{i}.variables, varName);
    iGood = true(size(sample_data{i}.dimensions{iTime}.data));
        
    % the variable exists, is QC'd and is 1D
    if isQC && iVar && size(sample_data{i}.variables{iVar}.data, 2) == 1
        %get time and var QC information
        timeFlags = sample_data{i}.dimensions{iTime}.flags;
        varFlags = sample_data{i}.variables{iVar}.flags;
        
        iGood = (timeFlags == 1 | timeFlags == 2) & (varFlags == 1 | varFlags == 2);
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

markerStyle = {'+', 'o', '*', '.', 'x', 's', 'd', '^', 'v', '>', '<', 'p', 'h'};
lenMarkerStyle = length(markerStyle);

instrumentDesc = cell(lenSampleData + 1, 1);
hScatterVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'Make Model (nominal depth - instrument SN)';
hScatterVar(1) = 0;

% we need to go through every instruments to figure out the CLim properties
% on which the subset plots happen below.
minClim = NaN;
maxClim = NaN;
isPlottable = false(1, lenSampleData);
for i=1:lenSampleData
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    iDepth = getVar(sample_data{iSort(i)}.variables, 'DEPTH');
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && iDepth > 0 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 && ... % we're only plotting 1D variables with depth variable but no current
            all(~strcmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3'}))
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        if isQC
            %get time, depth and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGood = (timeFlags == 1 | timeFlags == 2) & (varFlags == 1 | varFlags == 2) & (depthFlags == 1 | depthFlags == 2);
        end
        
        if any(iGood)
            isPlottable(i) = true;
            minClim = min(minClim, min(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
            maxClim = max(maxClim, max(sample_data{iSort(i)}.variables{iVar}.data(iGood)));
        end
    end
end

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
        iVar = getVar(sample_data{iSort(i)}.variables, varName);
        
        if isPlottable(i)
            if initiateFigure
                fileName = genIMOSFileName(sample_data{iSort(i)}, 'png');
                visible = 'on';
                if saveToFile, visible = 'off'; end
                hFigMooringVar = figure(...
                    'Name', title, ...
                    'NumberTitle','off', ...
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
                
                hCBar = colorbar('peer', hAxMooringVar);
                set(get(hCBar, 'Title'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
                
                initiateFigure = false;
            end
            
            iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
            iGoodDepth = iGood;
            
            if isQC
                %get time, depth and var QC information
                timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
                depthFlags = sample_data{iSort(i)}.variables{iDepth}.flags;
                varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
                varValues = sample_data{iSort(i)}.variables{iVar}.data;
                
                iGood = (timeFlags == 1 | timeFlags == 2) & ...
                    (varFlags == 1 | varFlags == 2) & ...
                    ~isnan(varValues);
                iGoodDepth = (depthFlags == 1 | depthFlags == 2);
            end
            
            if all(~iGood) && isQC
                fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                    ', there is not any ' varName ' data with good flags.']);
                continue;
            else
                depth = sample_data{iSort(i)}.variables{iDepth}.data;
                depth(~iGoodDepth) = metaDepth(i);
                depth = depth(iGood);
                
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
                        sample_data{iSort(i)}.variables{iVar}.data(iGood), ...
                        markerStyle{mod(i, lenMarkerStyle)+1}, ...
                        [minClim maxClim]);
                else
                    h = scatter(hAxMooringVar, ...
                        sample_data{iSort(i)}.dimensions{iTime}.data(iGood), ...
                        depth, ...
                        5, ...
                        sample_data{iSort(i)}.variables{iVar}.data(iGood), ...
                        markerStyle{mod(i, lenMarkerStyle)+1}, ...
                        MarkerFaceColor, 'none');
                end
                
                if ~isempty(h), hScatterVar(i + 1) = h; end
                
                % Let's redefine properties after pcolor to make sure grid lines appear
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
    if nLine > 2
        nLine1 = ceil(nLine/2);
        
        hLegend(1) = multipleLegend(hAxMooringVar, ...
            hScatterVar(1:nLine1),  instrumentDesc(1:nLine1), ...
            'Interpreter',          'none', ...
            'Location',             'SouthOutside');
        hLegend(2) = multipleLegend(hAxMooringVar, ...
            hScatterVar(nLine1+1:nLine),    instrumentDesc(nLine1+1:nLine), ...
            'Interpreter',                  'none', ...
            'Location',                     'SouthOutside');
        
        posAx = get(hAxMooringVar, 'Position');

        pos1 = get(hLegend(1), 'Position');
        pos2 = get(hLegend(2), 'Position');
        maxWidth = max(pos1(3), pos2(3));

        set(hLegend(1), 'Position', [posAx(1), pos1(2), pos1(3), pos1(4)]);
        set(hLegend(2), 'Position', [posAx(3) - maxWidth/2, pos1(2), pos2(3), pos2(4)]);
        
        % set position on legends above modifies position of axis so we
        % re-initialise it
        set(hAxMooringVar, 'Position', posAx);
    else
        % doesn't make sense to continue and export to file since seing a
        % scatter plot in depth only helps to analyse the data in its
        % context that is to say with nearest similar datasets.
        close(hFigMooringVar);
        return;
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