function [ iBigMonitor ] = getBiggestMonitor()
%GETBIGGESTMONITOR Returns the logical index of your biggest monitor
%

monitorPos = get(0,'MonitorPosition');

switch computer
    case {'PCWIN', 'PCWIN64'}
        % [xmin2,ymin2,xmax2,ymax2;
        %  xmin1,ymin1,xmax1,ymax1]
        % The last row corresponds to device 1. The monitor labeled as device 1 in the Windows control
        % panel remains the reference monitor that defines the position of the
        % origin. The values for minimum and maximum are relative to the origin.
        width = monitorPos(:, 3)-monitorPos(:, 1);
        
    case 'GLNXA64'
        % [xP yP widthP heightP;
        %  xS yS widthS heightS]
        % The upper-left corner of a rectangle enclosing the system monitors forms the origin.
        % Where the values represent the offset from the left (x),
        % the offset from the top (y), and the width and
        % height of the monitor.
        width = monitorPos(:, 3);
        
    case 'MACI64'
        % [x,y,width,height-menuHieght]
        % MATLAB on Macintosh systems recognize only the main monitor.
        % Where the values are x = 0, y =0, monitor width, and monitor height minus the height of
        % the menubar. The main monitor is determined by which display has the menu bar.
        width = monitorPos(:, 3);
end

iBigMonitor = width == max(width);
        
% in case exactly same biggest monitors more than once we return the first one
if sum(iBigMonitor)>1
    firstBigMonitor = find(iBigMonitor, 1, 'first');
    iBigMonitor(:) = false;
    iBigMonitor(firstBigMonitor) = true;
end

end