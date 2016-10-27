function fastSaveas( hFig, hPanel, fileDestination )
%FASTSAVEAS is a faster alternative to saveas. 
% It is used to save diagnostic plots when exporting netCDF files.

% preserve the color scheme
set(hFig, 'InvertHardcopy', 'off');

drawnow;

% force figure full screen
try
    warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    frame_h = get(handle(hFig), 'JavaFrame');
    set(frame_h, 'Maximized', 1);
catch
    disp(['Warning : JavaFrame feature not supported. Figure is going full ' ...
        'screen using normalised units which does not give best results.']);
    oldUnits = get(hFig, 'Units');
    set(hFig, 'Units', 'norm', 'Pos', [0, 0, 1, 1]);
    set(hFig, 'Units', oldUnits);
end

% screencapture creates an image of what is really displayed on
% screen.
imwrite(screencapture(hPanel), fileDestination);

end

