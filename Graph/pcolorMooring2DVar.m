function pcolorMooring2DVar(sample_data, varName, isQC, saveToFile, exportDir)
%PCOLORMOORING2DVAR Opens a new window where the selected 2D
% variables collected by an intrument on the mooring are plotted.
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

varTitle = imosParameters(varName, 'long_name');
varUnit = imosParameters(varName, 'uom');

stringQC = 'non QC';
if isQC, stringQC = 'QC'; end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

title = [sample_data{1}.deployment_code ' mooring''s instruments ' stringQC '''d good ' varTitle];

% retrieve good flag values
qcSet     = str2double(readProperty('toolbox.qc_set'));
rawFlag   = imosQCFlag('raw', qcSet, 'flag');
goodFlag  = imosQCFlag('good', qcSet, 'flag');
pGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
goodFlags = [rawFlag, goodFlag, pGoodFlag];

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

% somehow could not get any data to plot, bail early
if any(isnan([xMin, xMax]))
    fprintf('%s\n', ['Warning : there is not any ' varName ' data in this deployment with good flags.']);
    return;
end

instrumentDesc = cell(lenSampleData, 1);
hPcolorVar = nan(lenSampleData, 1);

initiateFigure = true;

for i=1:lenSampleData
    % instrument description
    if ~isempty(strtrim(sample_data{iSort(i)}.instrument))
        instrumentDesc{i} = sample_data{iSort(i)}.instrument;
    elseif ~isempty(sample_data{iSort(i)}.toolbox_input_file)
        [~, instrumentDesc{i}] = fileparts(sample_data{iSort(i)}.toolbox_input_file);
    end
    
    instrumentSN = '';
    if ~isempty(strtrim(sample_data{iSort(i)}.instrument_serial_number))
        instrumentSN = [' - ' sample_data{iSort(i)}.instrument_serial_number];
    end
    
    instrumentDesc{i} = [strrep(instrumentDesc{i}, '_', ' ') ' (' num2str(metaDepth(i)) 'm' instrumentSN ')'];
        
    switch varName(1:4)
        case {'UCUR', 'VCUR', 'WCUR', 'VEL1', 'VEL2', 'VEL3'}   % 0 centred parameters
            cMap = 'r_b';
            cType = 'centeredOnZero';
        case {'CDIR', 'SSWD'}           % directions [0; 360[
            cMap = 'rkbwr';
            cType = 'direction';
        case {'CSPD'}                   % [0; oo[ paremeters 
            cMap = 'parula';
            cType = 'positiveFromZero';
        otherwise
            cMap = 'parula';
            cType = '';
    end
    
    %look for time and relevant variable
    iTime = getVar(sample_data{iSort(i)}.dimensions, 'TIME');
    nameHeight = 'HEIGHT_ABOVE_SENSOR';
    iHeight = getVar(sample_data{iSort(i)}.dimensions, nameHeight);
    if iHeight == 0
        nameHeight = 'DIST_ALONG_BEAMS';
        % is equivalent when tilt is negligeable
        iHeight = getVar(sample_data{iSort(i)}.dimensions, nameHeight);
    end
    iVar = getVar(sample_data{iSort(i)}.variables, varName);
    
    if iVar > 0 && iHeight > 0 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 2) > 1 && ...
            size(sample_data{iSort(i)}.variables{iVar}.data, 3) == 1 % we're only plotting ADCP 2D variables
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
            
            set(get(hAxMooringVar, 'XLabel'), 'String', 'Time');
            set(get(hAxMooringVar, 'YLabel'), 'String', [nameHeight ' (m)'], 'Interpreter', 'none');
            set(get(hAxMooringVar, 'Title'), 'String', sprintf('%s\n%s', title, instrumentDesc{i}), 'Interpreter', 'none');
            set(hAxMooringVar, 'XTick', (xMin:(xMax-xMin)/4:xMax));
            set(hAxMooringVar, 'XLim', [xMin, xMax]);
            hold(hAxMooringVar, 'on');
            
            initiateFigure = false;
        end
        
%         hLineVar(end) = line([xMin, xMax], [metaDepth(i), metaDepth(i)], ...
%             'Color', 'black');
            
        iGood = true(size(sample_data{iSort(i)}.variables{iVar}.data));
        
        if isQC
            %get time and var QC information
            timeFlags = sample_data{iSort(i)}.dimensions{iTime}.flags;
            varFlags = sample_data{iSort(i)}.variables{iVar}.flags;
            
            iGoodTime = ismember(timeFlags, goodFlags);
            nGoodTime = sum(iGoodTime);
            
            iGood = repmat(iGoodTime, [1, size(sample_data{iSort(i)}.variables{iVar}.data, 2)]);
            iGood = iGood & ismember(varFlags, goodFlags);
            
            iGoodHeight = any(iGood, 1);
            nGoodHeight = sum(iGoodHeight);
            nGoodHeight = nGoodHeight + 1;
            iGoodHeight(nGoodHeight) = 1;
        end
        
        if all(all(~iGood)) && isQC
            fprintf('%s\n', ['Warning : in ' sample_data{iSort(i)}.toolbox_input_file ...
                ', there is not any ' varName ' data with good flags.']);
        else
            xPcolor = sample_data{iSort(i)}.dimensions{iTime}.data(iGoodTime);
            yPcolor = sample_data{iSort(i)}.dimensions{iHeight}.data(iGoodHeight);
            dataVar = sample_data{iSort(i)}.variables{iVar}.data;
            dataVar(~iGood) = NaN;
            iGoodHeight = repmat(iGoodHeight, [nGoodTime, 1]);
            dataVar(~iGoodHeight) = [];
            dataVar = reshape(dataVar, nGoodTime, nGoodHeight);
            
            hPcolorVar(i) = pcolor(hAxMooringVar, double(xPcolor), double(yPcolor), double(dataVar'));
            set(hPcolorVar(i), 'FaceColor', 'flat', 'EdgeColor', 'none');

            % Let's redefine properties after pcolor to make sure grid lines appear
            % above color data and XTick and XTickLabel haven't changed
            set(hAxMooringVar, ...
                'XTick',        (xMin:(xMax-xMin)/4:xMax), ...
                'XGrid',        'on', ...
                'YGrid',        'on', ...
                'YDir',         'normal', ...
                'Layer',        'top');
            
            hCBar = colorbar('peer', hAxMooringVar);
            colormap(hAxMooringVar, cMap);
            
            switch cType
                case 'direction'
                    hCBar = colorbar('peer', hAxMooringVar, 'YLim', [0 360], 'YTick', [0 90 180 270 360]);
                    set(hAxMooringVar, 'CLim', [0 360]);
                    set(hCBar, 'YTick', [0 90 180 270 360]);
                case 'centeredOnZero'
                    yLimMax = max(max(dataVar));
                    hCBar = colorbar('peer', hAxMooringVar, 'YLim', [-yLimMax yLimMax]);
                    set(hAxMooringVar, 'CLim', [-yLimMax yLimMax]);
                case 'positiveFromZero'
                    yLimMax = max(max(dataVar));
                    hCBar = colorbar('peer', hAxMooringVar, 'YLim', [0 yLimMax]);
                    set(hAxMooringVar, 'CLim', [0 yLimMax]);
            end
            
            set(get(hCBar, 'Title'), 'String', [varName ' (' varUnit ')'], 'Interpreter', 'none');

            % set background to be grey
            set(hAxMooringVar, 'Color', [0.75 0.75 0.75])
        end
    end
end

if ~initiateFigure
    iNan = isnan(hPcolorVar);
    if any(iNan)
        hPcolorVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    datetick(hAxMooringVar, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    if saveToFile
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_PCOLOR_');
        
        fastSaveas(hFigMooringVar, fullfile(exportDir, fileName));
        
        close(hFigMooringVar);
    end
end

end