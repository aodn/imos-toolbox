function lineCastVar(sample_data, varNames, isQC, saveToFile, exportDir)
%LINECASTVAR Opens a new window where the selected
% variables collected by the CTD are plotted.
%
% Inputs:
%   sample_data - cell array of structs containing the entire data set and dimension data.
%
%   varNames    - cell array of strings containing the IMOS code for requested parameter.
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
if ~iscellstr(varNames),    error('varNames must be a cell array');     end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

% we get rid of specific parameters
notNeededParams = {'TIME', 'PROFILE', 'DIRECTION', 'LATITUDE', 'LONGITUDE', 'BOT_DEPTH', 'PRES', 'PRES_REL', 'DEPTH'};
for i=1:length(notNeededParams)
    iNotNeeded = strcmpi(varNames, notNeededParams{i});
    varNames(iNotNeeded) = [];
end

%plot depth information
monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

title = [sample_data{1}.site_code ' profile on ' datestr(sample_data{1}.time_coverage_start, 'yyyy-mm-dd UTC')];

initiateFigure = true;

lenVarNames = length(varNames);
for k=1:lenVarNames
    varName = varNames{k};
    
    varTitle = imosParameters(varName, 'long_name');
    varUnit = imosParameters(varName, 'uom');
    
    lenSampleData = length(sample_data);
    yMin = nan(lenSampleData, 1);
    yMax = nan(lenSampleData, 1);
    for i=1:lenSampleData
        type = 'dimensions';
        iDepth = getVar(sample_data{i}.(type), 'DEPTH');
        if iDepth == 0
            type = 'variables';
            iDepth = getVar(sample_data{i}.(type), 'DEPTH');
        end
        yMin(i) = min(sample_data{i}.(type){iDepth}.data);
        yMax(i) = max(sample_data{i}.(type){iDepth}.data);
    end
    yMin = min(yMin);
    yMax = max(yMax);
    
    instrumentDesc = cell(lenSampleData + 1, 1);
    hLineVar = nan(lenSampleData + 1, 1);
    flagDesc = cell(4, 1);
    hLineFlag = ones(4, 1);
    
    instrumentDesc{1} = 'Make Model (instrument SN - cast time)';
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
        
        instrumentDesc{i + 1} = [strrep(instrumentDesc{i + 1}, '_', ' ') ' (' instrumentSN ' - ' datestr(sample_data{i}.time_coverage_start, 'yyyy-mm-dd HH:MM UTC') ')'];
        
        %look for depth and relevant variable
        type = 'dimensions';
        iDepth = getVar(sample_data{i}.(type), 'DEPTH');
        if iDepth == 0
            type = 'variables';
            iDepth = getVar(sample_data{i}.(type), 'DEPTH');
        end
        iVar = getVar(sample_data{i}.variables, varName);
        
        if iVar > 0
            if initiateFigure
                fileName = genIMOSFileName(sample_data{i}, 'png');
                hFigCastVar = figure(...
                    'Name', title, ...
                    'NumberTitle','off', ...
                    'OuterPosition', monitorRect(iBigMonitor, :));
                
                % create uipanel within figure so that screencapture can be
                % used on the plot only and without capturing all of the figure
                % (including buttons, menus...)
                hPanelCastVar = uipanel('Parent', hFigCastVar);
                
                initiateFigure = false;
            end
                       
            if i==1
                hAxCastVar = subplot(1, lenVarNames, k, 'Parent', hPanelCastVar);
                set(hAxCastVar, 'YDir', 'reverse');
                set(get(hAxCastVar, 'Title'), 'String', title, 'Interpreter', 'none');
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
                
                cMap = colormap(hAxCastVar, parula(lenSampleData));
                cMap = flipud(cMap);
            end
            
            yLine = sample_data{i}.(type){iDepth}.data;
            dataVar = sample_data{i}.variables{iVar}.data;
            
            hLineVar(i + 1) = line(dataVar, ...
                yLine, ...
                'Color', cMap(i, :));
            
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
            
            flagDesc{1} = imosQCFlag(flagGood, qcSet, 'desc');
            fc = imosQCFlag(flagGood, qcSet, 'color');
            hLineFlag(1) =  line(NaN, NaN, ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none', ...
                    'Visible', 'off'); % this is to make sure all flags are properly displayed within legend
            if any(iGood)
                hLineFlag(1) = line(dataVar(iGood), ...
                    yLine(iGood), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            flagDesc{2} = imosQCFlag(flagPGood, qcSet, 'desc');
            fc = imosQCFlag(flagPGood, qcSet, 'color');
            hLineFlag(2) =  line(NaN, NaN, ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none', ...
                    'Visible', 'off');
            if any(iProbablyGood)
                hLineFlag(2) = line(dataVar(iProbablyGood), ...
                    yLine(iProbablyGood), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            flagDesc{3} = imosQCFlag(flagPBad, qcSet, 'desc');
            fc = imosQCFlag(flagPBad, qcSet, 'color');
            hLineFlag(3) =  line(NaN, NaN, ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none', ...
                    'Visible', 'off');
            if any(iProbablyBad)
                hLineFlag(3) = line(dataVar(iProbablyBad), ...
                    yLine(iProbablyBad), ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none');
            end
            
            flagDesc{4} = imosQCFlag(flagBad, qcSet, 'desc');
            fc = imosQCFlag(flagBad, qcSet, 'color');
            hLineFlag(4) =  line(NaN, NaN, ...
                    'LineStyle', 'none', ...
                    'Marker', 'o', ...
                    'MarkerFaceColor', fc, ...
                    'MarkerEdgeColor', 'none', ...
                    'Visible', 'off');
            if any(iBad)
                hLineFlag(4) = line(dataVar(iBad), ...
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
        
        hLineVar = [hLineVar; hLineFlag];
        instrumentDesc = [instrumentDesc; flagDesc];
        
        hLegend = legend(hAxCastVar, ...
            hLineVar,       instrumentDesc, ...
            'Interpreter',  'none', ...
            'Location',     'SouthOutside');
        
        %     set(hLegend, 'Box', 'off', 'Color', 'none');
        if k <= lenVarNames/2 || k > lenVarNames/2 + 1
            set(hLegend, 'Visible', 'off');
            set(get(hAxCastVar, 'Title'), 'String', '', 'Interpreter', 'none');
        end
    end
    
end
    
if saveToFile
    fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_'); % IMOS_[sub-facility_code]_[platform_code]_FV01_[time_coverage_start]_[PLOT-TYPE]_C-[creation_date].png
    
    fastSaveas(hFigCastVar, hPanelCastVar, fullfile(exportDir, fileName));
    
    close(hFigCastVar);
end

end