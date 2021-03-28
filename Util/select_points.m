function [x,y] = select_points(hAx)
% function [x,y] = select_points(hAx)
%
% Interactively draw a rectangle in
% the current axis and extract its own coordinates.
%
% Inputs:
%
% hAx [graphics.axis.Axes] - a Matlab Axis class 
%
% Outputs:
%
% x [double] - a row vector of the start/end horizontal 
%              rectangle positions
% y [double] - a row vector of the start/end vertical
%              rectangle positions.
%
% Example:
%
% %manual evaluation
% % [x,y] = drawrectangle(gca());
% % % draw or click with mose
% % assert(isnumerical(x));
% % assert(isnumerical(y));
%
%
% author: Rebecca Cowley
%         hugo.oliveira@utas.edu.au
%
if isdeployed || license('test', 'Image_Toolbox')
    rec = drawrectangle(hAx);
    x = [rec.Position(1) rec.Position(1) + rec.Position(3)];
    y = [rec.Position(2) rec.Position(2) + rec.Position(4)];
    delete(rec);
else
    axes(hAx);
    disableDefaultInteractivity(hAx);
    waitforbuttonpress;
    point1 = get(gca, 'CurrentPoint'); % button down detected
    rbbox; % return figure units
    point2 = get(gca, 'CurrentPoint'); % button up detected
    disableDefaultInteractivity(hAx);
    point1 = point1(1, 1:2); % extract x and y
    point2 = point2(1, 1:2);
    p1 = min(point1, point2); % calculate locations
    offset = abs(point1 - point2); % and dimensions
    x = [p1(1) p1(1) + offset(1) p1(1) + offset(1) p1(1) p1(1)];
    y = [p1(2) p1(2) p1(2) + offset(2) p1(2) + offset(2) p1(2)];
    hold on
    axis manual
    plot(x, y); % redraw in dataspace units
end

end
