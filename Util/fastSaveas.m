function fastSaveas( hFig, fileDestination )
%FASTSAVEAS is a faster alternative to saveas. 
% It is used to save diagnostic plots when exporting netCDF files.

% ensure the printed version is the same whatever the screen used.
set(hFig, ...
    'PaperPositionMode',    'manual', ...
    'PaperType',            'A4', ...
    'PaperOrientation',     'landscape', ...
    'InvertHardcopy',       'off'); % preserve the color scheme

switch computer
    case 'GLNXA64'
        set(hFig, ...
            'Position',         [10 10 1920 1200]); % set static figure resolution (some linux go fullscreen across every screen!)
        
    otherwise
        set(hFig, ...
            'PaperUnits',       'normalized', ...
            'PaperPosition',    [0 0 1 1]); % set figure resolution to full screen (as big as possible to fit the legend)
        
end

drawnow; % Forces GUI to update itself, otherwise colorbar might be missing

% use hgexport to print to file as close as possible as what we see
myStyle = hgexport('factorystyle');
myStyle.Format     = 'png'; % (default is eps)
myStyle.Background = [0.75 0.75 0.75]; % grey (default is white)

hgexport(hFig, fileDestination, myStyle);

end

