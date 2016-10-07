function fastSaveas( hFig, fileDestination )
%FASTSAVEAS is a faster alternative to saveas. 
% It is used to save diagnostic plots when exporting netCDF files.

% ensure the printed version is the same whatever the screen used.
set(hFig, 'PaperPositionMode', 'manual');
set(hFig, 'PaperType', 'A4', 'PaperOrientation', 'landscape', 'PaperUnits', 'normalized', 'PaperPosition', [0, 0, 1, 1]);

% preserve the color scheme
set(hFig, 'InvertHardcopy', 'off');

% use hardcopy as a trick to go faster than saveas.
% opengl (hardware or software) should be supported by any platform and go at least just as
% fast as zbuffer. With hardware accelaration supported, could even go a
% lot faster.
imwrite(hardcopy(hFig, '-dopengl'), fileDestination);

end

