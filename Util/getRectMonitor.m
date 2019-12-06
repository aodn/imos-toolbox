function [ monitorRect ] = getRectMonitor()
%GETRECTMONITOR Returns a 4 element vector rect = [left, bottom, width, height]
%where left and bottom define the distance from the lower-left corner of the biggest screen to the lower-left
%corner of the full figure window. width and height define the dimensions of the window. See the Units property
%for information on the units used in this specification. The left and bottom elements
%can be negative on systems that have more than one monitor.
%

monitorRect = get(0,'MonitorPosition');

switch computer
    case {'PCWIN', 'PCWIN64'}
        % we need to convert from:
        % [xmin2,ymin2,xmax2,ymax2;
        %  xmin1,ymin1,xmax1,ymax1]
        % The last row corresponds to device 1. The monitor labeled as device 1 in the Windows control
        % panel remains the reference monitor that defines the position of the
        % origin. The values for minimum and maximum are relative to the origin.
        xMin = monitorRect(:, 1);
        yMin = monitorRect(:, 2);
        xMax = monitorRect(:, 3);
        yMax = monitorRect(:, 4);
        
        width = xMax - xMin + 1;
        height = yMax - yMin + 1;
        
        heightFullRect = max(yMax) - min(yMin) + 1;
        
        left = xMin - 1;
        bottom = heightFullRect - (yMin - 1 + height);
        
    case 'GLNXA64'
        % we need to convert from:
        % [xP yP widthP heightP;
        %  xS yS widthS heightS]
        % The upper-left corner of a rectangle enclosing the system monitors forms the origin.
        % Where the values represent the offset from the left (x),
        % the offset from the top (y), and the width and
        % height of the monitor.
        xP = monitorRect(:, 1);
        yP = monitorRect(:, 2);
        widthP = monitorRect(:, 3);
        heightP = monitorRect(:, 4);
        
        heightFullRect = max(yP + heightP);
        
        left = xP;
        bottom = heightFullRect - (yP + heightP);
        width = widthP;
        height = heightP;
        
    case 'MACI64'
        % we need to convert from:
        % [x,y,width,height-menuHieght]
        % MATLAB on Macintosh systems recognize only the main monitor.
        % Where the values are x = 0, y =0, monitor width, and monitor height minus the height of
        % the menubar. The main monitor is determined by which display has the menu bar.
        left = monitorRect(:, 1);
        bottom = monitorRect(:, 2);
        width = monitorRect(:, 3);
        height = monitorRect(:, 4);
        
end

monitorRect = [left, bottom, width, height];

end