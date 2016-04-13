function lineMooring2DVarSection(sample_data, varName, timeValue, isQC, saveToFile, exportDir)
%LINEMOORING2DVARSECTION Opens a new window where the clicked 2D graph in TIME see
% its variable plotted accross the 2nd dimension.
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%
%   varName     - string containing the IMOS code for requested parameter.
%
%   timeValue   - double time when the plot must be performed.
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
narginchk(6,6);

if ~isstruct(sample_data),  error('sample_data must be a struct');      end
if ~ischar(varName),        error('varName must be a string');          end
if ~isnumeric(timeValue),   error('timeValue must be a number');        end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

%plot depth information
monitorRec = get(0,'MonitorPosition');
xResolution = monitorRec(:, 3)-monitorRec(:, 1);
iBigMonitor = xResolution == max(xResolution);
if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors

iVar = getVar(sample_data.variables, varName);
title = [sample_data.variables{iVar}.name ' section of ' sample_data.deployment_code ' at ' datestr(timeValue, 'yyyy-mm-dd HH:MM:SS UTC')];

initiateFigure = true;
    
varTitle = imosParameters(varName, 'long_name');
varUnit = imosParameters(varName, 'uom');

if ~isempty(sample_data.meta.depth)
    metaDepth = sample_data.meta.depth;
elseif ~isempty(sample_data.instrument_nominal_depth)
    metaDepth = sample_data.instrument_nominal_depth;
else
    metaDepth = NaN;
end

instrumentDesc = cell(2, 1);
hLineVar = nan(2, 1);
flagDesc = cell(4, 1);
hLineFlag = ones(4, 1);

instrumentDesc{1} = 'Make Model (nominal_depth - instrument SN)';
hLineVar(1) = 0;

% instrument description
if ~isempty(strtrim(sample_data.instrument))
    instrumentDesc{2} = sample_data.instrument;
elseif ~isempty(sample_data.toolbox_input_file)
    [~, instrumentDesc{2}] = fileparts(sample_data.toolbox_input_file);
end

instrumentSN = '';
if ~isempty(strtrim(sample_data.instrument_serial_number))
    instrumentSN = sample_data.instrument_serial_number;
end

instrumentDesc{2} = [strrep(instrumentDesc{2}, '_', ' ') ' (' num2str(metaDepth) 'm - ' instrumentSN ')'];

%look for 2nd dimension and relevant variable
iVar = getVar(sample_data.variables, varName);
iTime = getVar(sample_data.dimensions, 'TIME');
i2Ddim = sample_data.variables{iVar}.dimensions(2);

diff = abs(sample_data.dimensions{iTime}.data - timeValue);
iX = min(diff) == diff;
n2Ddim = length(sample_data.dimensions{i2Ddim}.data);
iX = repmat(iX, [1 n2Ddim]);

dimName = sample_data.dimensions{i2Ddim}.name;
dimTitle = imosParameters(dimName, 'long_name');
dimUnit = imosParameters(dimName, 'uom');

backgroundColor = [0.75 0.75 0.75];

if iVar > 0
    if initiateFigure
        fileName = genIMOSFileName(sample_data, 'png');
        visible = 'on';
        if saveToFile, visible = 'off'; end
        hFigVarSection = figure(...
            'Name', title, ...
            'NumberTitle','off', ...
            'Visible', visible, ...
            'OuterPosition', [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);
        
        initiateFigure = false;
    end
    
    hAxCastVar = axes;
    set(get(hAxCastVar, 'Title'), 'String', title, 'Interpreter', 'none');
    set(get(hAxCastVar, 'XLabel'), 'String', [varTitle ' (' varUnit ')'], 'Interpreter', 'none');
    set(get(hAxCastVar, 'YLabel'), 'String', [dimTitle ' (' dimUnit ')'], 'Interpreter', 'none');
    
    hold(hAxCastVar, 'on');
    
    % dummy entry for first entry in legend
    hLineVar(1) = plot(0, 0, 'o', 'color', backgroundColor, 'Visible', 'off'); % color grey same as background (invisible)
    
    yLine = sample_data.dimensions{i2Ddim}.data;
    dataVar = sample_data.variables{iVar}.data(iX);
    
    hLineVar(2) = line(dataVar, ...
        yLine, ...
        'LineStyle', '-');
    
    xLim = get(hAxCastVar, 'XLim');
    yLim = get(hAxCastVar, 'YLim');
    
    %get var QC information
    varFlags = sample_data.variables{iVar}.flags(iX);
    
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
        fprintf('%s\n', ['Warning : in ' sample_data.toolbox_input_file ...
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
    set(hAxCastVar, 'Color', backgroundColor)
end

if ~initiateFigure
    iNan = isnan(hLineVar);
    if any(iNan)
        hLineVar(iNan) = [];
        instrumentDesc(iNan) = [];
    end
    
    hLineVar = [hLineVar; hLineFlag];
    instrumentDesc = [instrumentDesc; flagDesc];
    % Matlab >R2015 legend entries for data which are not plotted 
	% will be shown with reduced opacity
    hLegend = legend(hAxCastVar, ...
        hLineVar,       regexprep(instrumentDesc,'_','\_'), ...
        'Interpreter',  'none', ...
        'Location',     'SouthOutside');
    %     set(hLegend, 'Box', 'off', 'Color', 'none');
end
    
if saveToFile
    % ensure the printed version is the same whatever the screen used.
    set(hFigVarSection, 'PaperPositionMode', 'manual');
    set(hFigVarSection, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
    
    % preserve the color scheme
    set(hFigVarSection, 'InvertHardcopy', 'off');
    
    fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_'); % IMOS_[sub-facility_code]_[platform_code]_FV01_[time_coverage_start]_[PLOT-TYPE]_C-[creation_date].png
    
    % use hardcopy as a trick to go faster than print.
    % opengl (hardware or software) should be supported by any platform and go at least just as
    % fast as zbuffer. With hardware accelaration supported, could even go a
    % lot faster.
    imwrite(hardcopy(hFigVarSection, '-dopengl'), fullfile(exportDir, fileName), 'png');
    
    close(hFigVarSection);
end

end