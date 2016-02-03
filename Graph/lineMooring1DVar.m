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

lineStyle = {'-', '--', ':', '-.'};
lenLineStyle = length(lineStyle);

instrumentDesc = cell(lenSampleData + 1, 1);
hLineVar = nan(lenSampleData + 1, 1);

instrumentDesc{1} = 'Make Model (nominal depth - instrument SN)';
hLineVar(1) = 0;

initiateFigure = true;
isPlottable = false;

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
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && size(sample_data{iSort(i)}.variables{iVar}.data, 2) == 1 && ... % we're only plotting 1D variables but no current
            all(~strcmpi(sample_data{iSort(i)}.variables{iVar}.name, {'UCUR', 'VCUR', 'WCUR', 'CDIR', 'CSPD', 'VEL1', 'VEL2', 'VEL3'}))        
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
            if any(strcmpi(varName, {'DEPTH', 'PRES', 'PRES_REL'})), set(hAxMooringVar, 'YDir', 'reverse'); end
            set(get(hAxMooringVar, 'XLabel'), 'String', 'Time');
            set(get(hAxMooringVar, 'YLabel'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');
            set(get(hAxMooringVar, 'Title'), 'String', title, 'Interpreter', 'none');
            set(hAxMooringVar, 'XTick', (xMin:(xMax-xMin)/4:xMax));
            set(hAxMooringVar, 'XLim', [xMin, xMax]);
            hold(hAxMooringVar, 'on');
            
            % reverse the colorbar as we want surface in red and bottom in blue
            cMap = colormap(hAxMooringVar, jet(lenSampleData));
            cMap = flipud(cMap);
            
            initiateFigure = false;
        end
        
        if strcmpi(varName, 'DEPTH')
            hLineVar(1) = line([xMin, xMax], [metaDepth(i), metaDepth(i)], ...
                'Color', 'black');
        end
        
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGood = (timeFlags == 1 | timeFlags == 2) & (varFlags == 1 | varFlags == 2);
        end
        
        if all(~iGood) && isQC
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', there is not any ' varName ' data with good flags.']);
            continue;
        else
            isPlottable = true;
            
            xLine = sample_data{iSort(i)}.dimensions{iTime}.data;
            xLine(~iGood) = NaN;
            
            dataVar = sample_data{iSort(i)}.variables{iVar}.data;
            dataVar(~iGood) = NaN;
    
            hLineVar(i + 1) = line(xLine, ...
                dataVar, ...
                'Color', cMap(i, :), ...
                'LineStyle', lineStyle{mod(i, lenLineStyle)+1});
            
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
    cb = colorbar('peer', hAxMooringVar);
    set(get(cb, 'YLabel'), 'String', 'TEST');
    pos_with_colorbar = get(hAxMooringVar, 'Position');
    colorbar(cb, 'off');
    set(hAxMooringVar, 'Position', pos_with_colorbar);
    
    datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend in two location horizontally
    nLine = length(hLineVar);
    if nLine > 2
        nLine1 = ceil(nLine/2);
        
        hLegend(1) = multipleLegend(hAxMooringVar, ...
            hLineVar(1:nLine1), instrumentDesc(1:nLine1), ...
            'Interpreter',      'none', ...
            'Location',         'SouthOutside');
        hLegend(2) = multipleLegend(hAxMooringVar, ...
            hLineVar(nLine1+1:nLine),   instrumentDesc(nLine1+1:nLine), ...
            'Interpreter',              'none', ...
            'Location',                 'SouthOutside');
        
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
        hLegend = legend(hAxMooringVar, ...
            hLineVar,       instrumentDesc, ...
            'Interpreter',  'none', ...
            'Location',     'SouthOutside');
        
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
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        % use hardcopy as a trick to go faster than print.
        % opengl (hardware or software) should be supported by any platform and go at least just as
        % fast as zbuffer. With hardware accelaration supported, could even go a
        % lot faster.
        imwrite(hardcopy(hFigMooringVar, '-dopengl'), fullfile(exportDir, fileName), 'png');
        close(hFigMooringVar);
    end
end

end