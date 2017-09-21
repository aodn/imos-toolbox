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
narginchk(6,6);

if ~isstruct(sample_data),  error('sample_data must be a struct');      end
if ~ischar(varName),        error('varName must be a string');          end
if ~isnumeric(timeValue),   error('timeValue must be a number');        end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

monitorRect = getRectMonitor();
iBigMonitor = getBiggestMonitor();

initiateFigure = true;
    
varTitle = imosParameters(varName, 'long_name');
varUnit  = imosParameters(varName, 'uom');

varDesc = cell(3, 1);
hLineVar = nan(3, 1);
flagDesc = cell(4, 1);
hLineFlag = ones(4, 1);

% instrument description
if ~isempty(strtrim(sample_data.instrument))
    instrumentDesc = sample_data.instrument;
elseif ~isempty(sample_data.toolbox_input_file)
    [~, instrumentDesc] = fileparts(sample_data.toolbox_input_file);
end

if ~isempty(sample_data.meta.depth)
    metaDepth = sample_data.meta.depth;
elseif ~isempty(sample_data.instrument_nominal_depth)
    metaDepth = sample_data.instrument_nominal_depth;
else
    metaDepth = NaN;
end

instrumentSN = '';
if ~isempty(strtrim(sample_data.instrument_serial_number))
    instrumentSN = sample_data.instrument_serial_number;
end

instrumentDesc = [strrep(instrumentDesc, '_', ' ') ' (' num2str(metaDepth) 'm - ' instrumentSN ')'];

title = [varName ' section of ' instrumentDesc ' from ' sample_data.deployment_code ' @ ' datestr(timeValue, 'yyyy-mm-dd HH:MM:SS UTC')];

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
dimUnit  = imosParameters(dimName, 'uom');

backgroundColor = [0.85 0.85 0.85];

if iVar > 0
    if initiateFigure
        fileName = genIMOSFileName(sample_data, 'png');
        visible = 'on';
        if saveToFile, visible = 'off'; end
        hFigVarSection = figure(...
            'Name',             title, ...
            'NumberTitle',      'off', ...
            'Visible',          visible, ...
            'OuterPosition',    monitorRect(iBigMonitor, :));
            
        initiateFigure = false;
    end
    
    hAxVarSection = axes;
    set(get(hAxVarSection, 'Title'), 'String', title, 'Interpreter', 'none');
    set(get(hAxVarSection, 'XLabel'), 'String', [varTitle ' (' varUnit ')'], 'Interpreter', 'none');
    set(get(hAxVarSection, 'YLabel'), 'String', [dimTitle ' (' dimUnit ')'], 'Interpreter', 'none');
    
    hold(hAxVarSection, 'on');
    
    yLine = sample_data.dimensions{i2Ddim}.data;
    dataVar = sample_data.variables{iVar}.data;
    dataVarProfile = dataVar(iX);
    
    % plot data profile
    hLineVar(1) = line(dataVarProfile, ...
        yLine, ...
        'LineStyle', '-');
    
    varDesc{1} = [varName ' @ ' datestr(timeValue, 'yyyy-mm-dd HH:MM:SS UTC')];
    
    % get var QC information
    flagsVar = sample_data.variables{iVar}.flags;
    flagsVarProfile = flagsVar(iX);
    
    qcSet = str2double(readProperty('toolbox.qc_set'));
    
    flagGood    = imosQCFlag('good',        qcSet, 'flag');
    flagPGood   = imosQCFlag('probablyGood',qcSet, 'flag');
    flagPBad    = imosQCFlag('probablyBad', qcSet, 'flag');
    flagBad     = imosQCFlag('bad',         qcSet, 'flag');
    
    iBad            = flagsVar == flagBad;
    iPBad           = flagsVar == flagPBad;
    
    iGoodProfile    = flagsVarProfile == flagGood;
    iPGoodProfile   = flagsVarProfile == flagPGood;
    iPBadProfile    = flagsVarProfile == flagPBad;
    iBadProfile     = flagsVarProfile == flagBad;
    
    if all(iPBadProfile | iBadProfile) && isQC
        fprintf('%s\n', ['Warning : in ' sample_data.toolbox_input_file ...
            ', there is not any ' varName ' data with good flags.']);
    end
    
    iMean = ~iBad & ~iPBad;
    nRows = size(dataVar, 2);
    dataVarMean = NaN(nRows, 1);
    dataVarStd  = NaN(nRows, 1);
    for j=1:nRows
        dataVarMean(j) = mean(dataVar(iMean(:, j), j));
        dataVarStd (j) = std (dataVar(iMean(:, j), j));
    end
    
    hLineVar(2) = line(dataVarMean, ...
        yLine, ...
        'LineStyle',    '--', ...
        'Color',        'g');
    
    varDesc{2} = [varName ' mean'];
    
    hLineVar(3) = line(dataVarMean + 3*dataVarStd, ...
        yLine, ...
        'LineStyle',    '--', ...
        'Color',        'r');
    
    line(dataVarMean - 3*dataVarStd, ...
        yLine, ...
        'LineStyle',    '--', ...
        'Color',        'r');
    
    varDesc{3} = [varName ' mean +/- 3*standard deviation'];
    
    flags         = [flagGood,     flagPGood,     flagPBad,     flagBad];
    iFlagsProfile = [iGoodProfile, iPGoodProfile, iPBadProfile, iBadProfile];
    
    % plot flags on top of data profile
    for i=1:4
        flagDesc{i} = imosQCFlag(flags(i), qcSet, 'desc');
        fc = imosQCFlag(flags(i), qcSet, 'color');
        hLineFlag(i) =  line(NaN, NaN, ...
            'LineStyle', 'none', ...
            'Marker', 'o', ...
            'MarkerFaceColor', fc, ...
            'MarkerEdgeColor', 'none', ...
            'Visible', 'off'); % this is to make sure all flags are properly displayed within legend
        if any(iFlagsProfile(:, i))
            hLineFlag(i) = line(dataVarProfile(iFlagsProfile(:, i)), ...
                yLine(iFlagsProfile(:, i)), ...
                'LineStyle', 'none', ...
                'Marker', 'o', ...
                'MarkerFaceColor', fc, ...
                'MarkerEdgeColor', 'none');
        end
    end
    
    % Let's redefine properties after line to make sure grid lines appear
    % above color data and XTick and XTickLabel haven't changed
    set(hAxVarSection, ...
        'XGrid',        'on', ...
        'YGrid',        'on', ...
        'Layer',        'top');
    
    % set background to be grey
    set(hAxVarSection, 'Color', backgroundColor)
end

if ~initiateFigure
    iNan = isnan(hLineVar);
    if any(iNan)
        hLineVar(iNan) = [];
        varDesc(iNan) = [];
    end
    
    hLineVar = [hLineVar; hLineFlag];
    varDesc = [varDesc; flagDesc];
    % Matlab >R2015 legend entries for data which are not plotted 
	% will be shown with reduced opacity
    legend(hAxVarSection, ...
        hLineVar,       regexprep(varDesc,'_','\_'), ...
        'Interpreter',  'none', ...
        'Location',     'SouthOutside');
end
    
if saveToFile
    fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_'); % IMOS_[sub-facility_code]_[platform_code]_FV01_[time_coverage_start]_[PLOT-TYPE]_C-[creation_date].png
    
    fastSaveas(hFigVarSection, fullfile(exportDir, fileName));
    
    close(hFigVarSection);
end

end