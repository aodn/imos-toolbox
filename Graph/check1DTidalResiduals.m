function check1DTidalResiduals(sample_data, iSampleMenu, iElev, isQC, saveToFile, exportDir)
% Opens a new window where the residuals between the pressure measurement 
% and the tidal prediction from analysis is plotted.
%
% Inputs:
%   sample_data - cell array of structs containing the entire data set and dimension data.
%
%   iSampleMenu - current Value of sampleMenu.
%
%   iElev       - index of pressure variable in sample_data.
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

if ~iscell(sample_data),    error('sample_data must be a cell array');  end
if ~islogical(isQC),        error('isQC must be a logical');            end
if ~islogical(saveToFile),  error('saveToFile must be a logical');      end
if ~ischar(exportDir),      error('exportDir must be a string');        end

isPlottable = false;

elevCode = sample_data{iSampleMenu}.variables{iElev}.name;
varTitle = sample_data{iSampleMenu}.variables{iElev}.long_name;
varUnit  = sample_data{iSampleMenu}.variables{iElev}.units;

stringQC = 'non QC';
if isQC, stringQC = 'QC'; end

%plot depth information
monitorRec = get(0,'MonitorPosition');
xResolution = monitorRec(:, 3)-monitorRec(:, 1);
iBigMonitor = xResolution == max(xResolution);
if sum(iBigMonitor)==2, iBigMonitor(2) = false; end % in case exactly same monitors

% extract elevation data
iTime = getVar(sample_data{iSampleMenu}.dimensions, 'TIME');

elevation   = sample_data{iSampleMenu}.variables{iElev}.data;
time        = sample_data{iSampleMenu}.dimensions{iTime}.data;

nSamples = length(time);

% drift = ((1:1:nSamples)'/nSamples);
% time = time + drift*5/(24*60); % linear drift that indroduces 5min offset at the end
% time = time + drift.^2*5/(24*60); % quadratic drift that indroduces 5min offset at the end
% elevation = elevation + drift*3; % linear drift that indroduces 3dBar offset at the end
% elevation = elevation + drift.^2*3; % quadratic drift that indroduces 3dBar offset at the end

iGood = true(size(time));
if isQC
    %get time and var QC information
    timeFlags = sample_data{iSampleMenu}.dimensions{iTime}.flags;
    elevFlags = sample_data{iSampleMenu}.variables{iElev}.flags;
    
    iGood = (timeFlags == 0 | timeFlags == 1 | timeFlags == 2) & (elevFlags == 1 | elevFlags == 2);
end
time(~iGood)      = [];
elevation(~iGood) = [];

if all(~iGood) && isQC
    fprintf('%s\n', ['Error : in ' sample_data{iSampleMenu}.toolbox_input_file ...
        ', there is not any pressure data with good flags.']);
    return;
end

% run tidal analysis:
% - 'white' option passed so that colored method for confidence interval is not
% used by default (Matlab Signal Processing Toolbox dependent).
% - 'OLS' and 'LinCI' options passed so that the IRLS solution method and
% the Monte Carlo confidence interval approach are not used by default
% (Matlab Statistics Toolbox dependent).
% coef = ut_solv(time, double(elevation), [], sample_data{iSampleMenu}.geospatial_lat_min, 'auto', 'white', 'OLS', 'LinCI');
coef = ut_solv(time, double(elevation), [], sample_data{iSampleMenu}.geospatial_lat_min, 'auto');

% run reconstruction:
tide = ut_reconstr(time, coef);

residuals = double(elevation)-tide;

% Pearson residuals
% http://au.mathworks.com/help/stats/residuals.html
rmsResiduals = sqrt(mean(residuals.^2));
residuals = residuals ./ sqrt(rmsResiduals);

% % we studentize the residuals
% oneArray = ones(size(time));
% designMat = [oneArray, time];
% hatMat = designMat / (designMat' * designMat) * designMat';
% clear designMat;
% oneDiag = diag(logical(oneArray));
% hII = hatMat(oneDiag);
% clear hatMat;
% zeroDiag = xor(true(size(oneDiag)), oneDiag);
% clear oneDiag;
% resMat = repmat(residuals, 1, length(time));
% MSE = mean((resMat.*zeroDiag).^2)';
% clear resMat zeroDiag;
% residuals = residuals ./ sqrt(MSE .* (oneArray-hII));

isPlottable = true;

% instrument description
if ~isempty(sample_data{iSampleMenu}.meta.depth)
    metaDepth = sample_data{iSampleMenu}.meta.depth;
elseif ~isempty(sample_data{iSampleMenu}.instrument_nominal_depth)
    metaDepth = sample_data{iSampleMenu}.instrument_nominal_depth;
else
    metaDepth = NaN;
end

if ~isempty(strtrim(sample_data{iSampleMenu}.instrument))
    instrumentDesc = sample_data{iSampleMenu}.instrument;
elseif ~isempty(sample_data{iSampleMenu}.toolbox_input_file)
    [~, instrumentDesc] = fileparts(sample_data{iSampleMenu}.toolbox_input_file);
end

instrumentSN = '';
if ~isempty(strtrim(sample_data{iSampleMenu}.instrument_serial_number))
    instrumentSN = [' - ' sample_data{iSampleMenu}.instrument_serial_number];
end

instrumentDesc = [strrep(instrumentDesc, '_', ' ') ' (' num2str(metaDepth) 'm' instrumentSN ')'];

title = [sample_data{iSampleMenu}.deployment_code ' - ' instrumentDesc ' 1D tidal analysis ' stringQC '''d'];

backgroundColor = [0.75 0.75 0.75];

%plot
fileName = genIMOSFileName(sample_data{iSampleMenu}, 'png');
visible = 'on';
if saveToFile, visible = 'off'; end
hFig1DTidalResiduals = figure(...
    'Name',             title, ...
    'NumberTitle',      'off', ...
    'Visible',          visible, ...
    'OuterPosition',    [0, 0, monitorRec(iBigMonitor, 3), monitorRec(iBigMonitor, 4)]);

%elevation/tide plot
hAxElevTide = subplot(2, 1, 1, 'Parent', hFig1DTidalResiduals);
set(hAxElevTide, 'YDir', 'reverse')
set(get(hAxElevTide, 'XLabel'), 'String', 'Time');
set(get(hAxElevTide, 'YLabel'), 'String', [elevCode ' (' varUnit ')'], 'Interpreter', 'none');
set(get(hAxElevTide, 'Title'), 'String', title , 'Interpreter', 'none');
hold(hAxElevTide, 'on');

%residuals plot
hAxResiduals = subplot(2, 1, 2, 'Parent', hFig1DTidalResiduals);
set(get(hAxResiduals, 'XLabel'), 'String', 'Time');
set(get(hAxResiduals, 'YLabel'), 'String', 'Pearson residuals', 'Interpreter', 'none');
titleRes = {['All constituents SNR = ' num2str(coef.diagn.SNRallc)]; ['RMS residuals = ' num2str(rmsResiduals)]};
set(get(hAxResiduals, 'Title'), 'String', titleRes , 'Interpreter', 'none');
hold(hAxResiduals, 'on');

%now plot the data of interest:
hLineElev = line(time, elevation, ...
    'Color', 'k', ...
    'LineStyle', '-', ...
    'Parent', hAxElevTide);

hLineTide = line(time, tide, ...
    'Color', 'r', ...
    'LineStyle', '-', ...
    'Parent', hAxElevTide);
                
hPlotResiduals = line(time, residuals, ...
    'Color', 'b', ...
    'LineStyle', '-', ...
    'Parent', hAxResiduals);

linkaxes([hAxResiduals, hAxElevTide], 'x');
        
% set background to be grey
set(hAxElevTide, 'Color', backgroundColor)
set(hAxResiduals, 'Color', backgroundColor)

% Let's redefine properties after pcolor to make sure grid lines appear
% above color data and XTick and XTickLabel haven't changed
set(hAxElevTide, ...
    'XGrid',        'on', ...
    'YGrid',        'on', ...
    'Layer',        'top');

set(hAxResiduals, ...
    'XGrid',        'on', ...
    'YGrid',        'on', ...
    'Layer',        'top');

if isPlottable
    datetick(hAxResiduals, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    datetick(hAxElevTide, 'x', 'dd-mm-yy HH:MM:SS', 'keepticks');
    
    % we try to split the legend, maximum 3 columns
    fontSizeAx = get(hAxElevTide,'FontSize');
    fontSizeLb = get(get(hAxElevTide,'XLabel'),'FontSize');
    xscale = 0.9;
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
    hLegendElevTide = legendflex(hAxElevTide, ...
        {varTitle, 'Reconstructed tidal fit'}, ...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols, ...
        'FontSize', fontSizeAx, ...
        'xscale', xscale, ...
        'Interpreter', 'none');
    posAxElevTide = get(hAxElevTide, 'Position');
    set(hLegendElevTide, 'Units', 'Normalized', 'color', backgroundColor);
    
    hLegendResiduals = legendflex(hAxResiduals, ...
        {'Raw residuals divided by the root mean squared residuals'}, ...
        'anchor', [6 2], ...
        'buffer', [0 -hYBuffer], ...
        'ncol', nCols, ...
        'FontSize', fontSizeAx, ...
        'xscale', xscale, ...
        'Interpreter', 'none');
    posAxResiduals = get(hAxResiduals, 'Position');
    set(hLegendResiduals, 'Units', 'Normalized', 'color', backgroundColor);

    % for some reason this call brings everything back together while it
    % shouldn't have moved previously anyway...
    set(hAxElevTide, 'Position', posAxElevTide);
    set(hAxResiduals, 'Position', posAxResiduals);
    
    if saveToFile
        % ensure the printed version is the same whatever the screen used.
        set(hFig1DTidalResiduals, 'PaperPositionMode', 'manual');
        set(hFig1DTidalResiduals, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);
        
        % preserve the color scheme
        set(hFig1DTidalResiduals, 'InvertHardcopy', 'off');
        
        fileName = strrep(fileName, '_PARAM_', ['_', varName, '_']); % IMOS_[sub-facility_code]_[site_code]_FV01_[deployment_code]_[PLOT-TYPE]_[PARAM]_C-[creation_date].png
        fileName = strrep(fileName, '_PLOT-TYPE_', '_LINE_');
        
        % use hardcopy as a trick to go faster than print.
        % opengl (hardware or software) should be supported by any platform and go at least just as
        % fast as zbuffer. With hardware accelaration supported, could even go a
        % lot faster.
        imwrite(hardcopy(hFig1DTidalResiduals, '-dopengl'), fullfile(exportDir, fileName), 'png');
        close(hFig1DTidalResiduals);
    end
end

end