function fastSaveas( hFig, hPanel, fileDestination )
%FASTSAVEAS is a faster alternative to saveas. 
% It is used to save diagnostic plots when exporting netCDF files.

drawnow;

% preserve the color scheme
set(hFig, 'InvertHardcopy', 'off');

% force figure full screen
frame_h = get(handle(hFig), 'JavaFrame');
set(frame_h, 'Maximized', 1);

% screencapture creates an image of what is really displayed on
% screen.
imwrite(screencapture(hPanel), fileDestination);

end

