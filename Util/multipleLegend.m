function [leg,labelhandles,outH,outM] = multipleLegend(varargin)
%MULTIPLELEGEND Display multiple legends.
%   LEGEND(string1,string2,string3, ...) puts a legend on the current plot
%   using the specified strings as labels. LEGEND works on line graphs,
%   bar graphs, pie graphs, ribbon plots, etc.  You can label any
%   solid-colored patch or surface object.  The fontsize and fontname for
%   the legend strings matches the axes fontsize and fontname.
%
%   LEGEND(H,string1,string2,string3, ...) puts a legend on the plot
%   containing the handles in the vector H using the specified strings as
%   labels for the corresponding handles.
%
%   LEGEND(M), where M is a string matrix or cell array of strings, and
%   LEGEND(H,M) where H is a vector of handles to lines and patches also
%   works.
%
%   LEGEND(AX,...) puts a legend on the axes with handle AX.
%
%   LEGEND OFF removes the legend from the current axes and deletes
%   the legend handle.
%   LEGEND(AX,'off') removes the legend from the axis AX.
%
%   LEGEND TOGGLE toggles legend on or off.  If no legend exists for the
%   current axes one is created using default strings. The default
%   string for an object is the value of the DisplayName property
%   if it is non-empty and otherwise it is a string of the form
%   'data1','data2', etc.
%   LEGEND(AX,'toggle') toggles legend for axes AX
%
%   LEGEND HIDE makes legend invisible.
%   LEGEND(AX,'hide') makes legend on axes AX invisible.
%   LEGEND SHOW makes legend visible. If no legend exists for the
%   current axes one is created using default strings.
%   LEGEND(AX,'show') makes legend on axes AX visible.
%
%   LEGEND BOXOFF  makes legend background box invisible when legend is
%   visible.
%   LEGEND(AX,'boxoff') for axes AX makes legend background box invisible when
%   legend is visible.
%   LEGEND BOXON makes legend background box visible when legend is visible.
%   LEGEND(AX,'boxon') for axes AX making legend background box visible when
%   legend is visible.
%
%   LEGH = LEGEND returns the handle to legend on the current axes or
%   empty if none exists.
%
%
%   LEGEND(...,'Location',LOC) adds a legend in the specified
%   location, LOC, with respect to the axes.  LOC may be either a
%   1x4 position vector or one of the following strings:
%       'North'              inside plot box near top
%       'South'              inside bottom
%       'East'               inside right
%       'West'               inside left
%       'NorthEast'          inside top right (default for 2-D plots)
%       'NorthWest'           inside top left
%       'SouthEast'          inside bottom right
%       'SouthWest'          inside bottom left
%       'NorthOutside'       outside plot box near top
%       'SouthOutside'       outside bottom
%       'EastOutside'        outside right
%       'WestOutside'        outside left
%       'NorthEastOutside'   outside top right (default for 3-D plots)
%       'NorthWestOutside'   outside top left
%       'SouthEastOutside'   outside bottom right
%       'SouthWestOutside'   outside bottom left
%       'Best'               least conflict with data in plot
%       'BestOutside'        least unused space outside plot
%   If the legend does not fit in the 1x4 position vector the position
%   vector is resized around the midpoint to fit the preferred legend size.
%   Moving the legend manually by dragging with the mouse or setting
%   the Position property will set the legend Location property to 'none'.
%
%   LEGEND(...,'Orientation',ORIENTATION) creates a legend with the
%   legend items arranged in the specified ORIENTATION. Allowed
%   values for ORIENTATION are 'vertical' (the default) and 'horizontal'.
%
%   [LEGH,OBJH,OUTH,OUTM] = LEGEND(...) returns a handle LEGH to the
%   legend axes; a vector OBJH containing handles for the text, lines,
%   and patches in the legend; a vector OUTH of handles to the
%   lines and patches in the plot; and a cell array OUTM containing
%   the text in the legend.
%
%   Examples:
%       x = 0:.2:12;
%       plot(x,besselj(1,x),x,besselj(2,x),x,besselj(3,x));
%       legend('First','Second','Third','Location','NorthEastOutside')
%
%       b = bar(rand(10,5),'stacked'); colormap(summer); hold on
%       x = plot(1:10,5*rand(10,1),'marker','square','markersize',12,...
%                'markeredgecolor','y','markerfacecolor',[.6 0 .6],...
%                'linestyle','-','color','r','linewidth',2); hold off
%       legend([b,x],'Carrots','Peas','Peppers','Green Beans',...
%                 'Cucumbers','Eggplant')


%   Unsupported APIs for internal use:
%
%   LOC strings can be abbreviated NE, SO, etc or lower case.
%
%   LEGEND('-DynamicLegend') or LEGEND(AX,'-DynamicLegend')
%   creates a legend that adds new entries when new plots appear
%   in the peer axes.
%
%   LEGEND(LI,string1,string2,string3) creates a legend for legendinfo
%   objects LI with strings string1, etc.
%   LEGEND(LI,M) creates a legend for legendinfo objects LI where M is a
%   string matrix or cell array of strings corresponding to the legendinfo
%   objects.

%   Copyright 1984-2012 The MathWorks, Inc.

% First we check whether Handle Graphics uses MATLAB classes

if ishg2parent( varargin{:} )
    % Legend no longer supports more than one output argument
    % Warn the user and ignore additional output arguments.
    if nargout > 1
        warning(message('MATLAB:legend:maxlhs'));
    end

    if nargout == 0
        legendHGUsingMATLABClasses(varargin{:});
    else
        leg = legendHGUsingMATLABClasses(varargin{:});
        if nargout > 1
            % populate unsupported additional outputs if requested
            % @todo - return empty default object instead
            labelhandles = [];
            outH = [];
            outM = [];
        end
    end
else
    narg = nargin;
    if (narg > 1 && ischar(varargin{1}) && ~ischar(varargin{2}) && strcmp(varargin{1},'v6'))
        warning(message('MATLAB:legend:DeprecatedV6Argument'));
        if nargout == 0
            legendv6(varargin{2:end});
        elseif nargout == 1
            leg = legendv6(varargin{2:end});
        elseif nargout == 2
            [leg,labelhandles] = legendv6(varargin{2:end});
        else
            [leg,labelhandles,outH,outM] = legendv6(varargin{2:end});
        end
        return;
        
        % look for special callbacks into legend for V6 legend code
    elseif (narg==1 && ischar(varargin{1}) && ...
            isvector(varargin{1}) && ...
            size(varargin{1},2) == length(varargin{1}) && ...
            any(strcmp(varargin{1},{'DeleteLegend','ResizeLegend'})))
        legendv6(varargin{:});
        return;
        
    elseif (narg==2 && ischar(varargin{1}) && ...
            isvector(varargin{1}) && ...
            size(varargin{1},2) == length(varargin{1}) && ...
            any(strcmp(varargin{1},...
            {'EditLegend','ShowLegendPlot','RestoreSize','RecordSize'})))
        legendv6(varargin{:});
        return
    end
    % HANDLE FINDLEGEND CASES FIRST
    if narg==2 && ...
            ischar(varargin{1}) && ...
            isequal(lower(varargin{1}),'-find') && ...
            ~isempty(varargin{2}) && ...
            ishandle(varargin{2}) && ...
            strcmpi(get(varargin{2},'type'),'axes')
        if nargout<=1
            leg = find_legend(varargin{2});
        else
            [leg,labelhandles,outH,outM] = find_legend_info(varargin{2});
        end
        return;
    end
    
    old_currfig = get(0,'CurrentFigure');
    if ~isempty(old_currfig)
        old_currax = get(old_currfig,'CurrentAxes');
    end
    
    arg = 1;
    
    % GET AXES FROM INPUTS
    if narg > 0  && ~isempty(varargin{1}) && ...
            length(varargin{1})==1 && ...
            ishandle(varargin{1}) && ...
            ~isa(varargin{1},'scribe.legendinfo') && ...
            strcmp(get(varargin{1}(1),'type'),'axes') % legend(ax,...)
        ha = varargin{1}(1);
        arg = arg + 1;
    elseif narg > 0 && ~ischar(varargin{1}) && ...
            ~isempty(varargin{1}) && ...
            all(ishandle(varargin{1})) && ...
            ~any(isa(varargin{1},'scribe.legendinfo'))  % legend(children,strings,...)
        ha = ancestor(varargin{1}(1),'axes');
        if isempty(ha)
            error(message('MATLAB:legend:InvalidPeerParameter'));
        end
    else
        ha = gca;
    end
    
    % LOOK FOR -DEFAULTSTRINGS option flag
    dfltstrings=false;
    if narg >= arg && all(ischar(varargin{arg})) && ...
            all(strcmpi(varargin{arg},'-defaultstrings'))
        dfltstrings=true;
        arg = arg + 1;
    end
    
    % if axes is a legend use its plotaxes
    h = handle(ha);
    if isa(h,'scribe.colorbar') || isa(h,'scribe.legend');
        ha = double(h.axes);
    end
    h = [];
    
    % PROCESS REMAINING INPUTS
    msg = '';
    if narg < arg % legend
        if nargout<=1, % h = legend or legend with no outputs
            l = find_legend(ha);
            if isempty(l) && dfltstrings
                [l,msg]=make_legend(ha,{});
            end
            if nargout == 1, leg = l; end
        else % [h,objh,...] = legend
            [leg,labelhandles,outH,outM] = find_legend_info(ha);
            if isempty(leg) && dfltstrings
                [h,msg] = make_legend(ha,{}); %#ok
                [leg,labelhandles,outH,outM] = find_legend_info(ha);
            end
        end
        if ~isempty(msg)
            warning(msg);
        end
        return;
    elseif narg >= arg && ischar(varargin{arg})
        if strcmpi(varargin{arg},'off') || strcmpi(varargin{arg},'DeleteLegend')
            delete_legend(find_legend(ha));
        elseif strcmpi(varargin{arg},'resizelegend')
            % do nothing. there is no need for this call, but it exists in old
            % code that was needed when legend did not have listeners to keep
            % itself positioned (prior to R14).
        elseif strcmpi(varargin{arg},'toggle')
            l=find_legend(ha);
            if isempty(l) || strcmpi(get(l,'Visible'),'off')
                legend(ha,'show');
            else
                legend(ha,'hide');
            end
        elseif strcmpi(varargin{arg},'show')
            l=find_legend(ha);
            if isempty(l)
                [h,msg] = make_legend(ha,varargin(arg+1:end));
            else
                set(l,'Visible','on');
            end
        elseif strcmpi(varargin{arg},'hide')
            l=find_legend(ha);
            if ~isempty(l)
                set(l,'Visible','off');
            end
        elseif strcmpi(varargin{arg},'boxon')
            l=handle(find_legend(ha));
            if ~isempty(l)
                set(l,'Visible','on');
            end
        elseif strcmpi(varargin{arg},'boxoff')
            lh=handle(find_legend(ha));
            if ~isempty(lh)
                lh.ObserveStyle='off';
                set(lh,'Visible','off');
                lh.ObserveStyle='on';
            end
        else
            [h,msg] = make_legend(ha,varargin(arg:end));
        end
    else % narg > 1
        [h,msg] = make_legend(ha,varargin(arg:end));
    end
    if ~isempty(msg)
        warning(msg);
    end
    
    % PROCESS OUTPUTS
    if nargout==0
    elseif nargout==1
        if isempty(h)
            leg = find_legend(ha);
        else
            leg = h;
        end
    elseif nargout==2
        [leg,labelhandles] = find_legend_labelhandles(ha);
    elseif nargout<=4
        [leg,labelhandles,outH,outM] = find_legend_info(ha);
    elseif nargout>4
        error(message('MATLAB:legend:BadNumberOfOutputs'));
    end
    
    % before going, be sure to reset current figure and axes
    if ~isempty(old_currfig) && ishandle(old_currfig) && ~strcmpi(get(old_currfig,'beingdeleted'),'on')
        set(0,'CurrentFigure',old_currfig);
        if ~isempty(old_currax) && ishandle(old_currax) && ~strcmpi(get(old_currax,'beingdeleted'),'on')
            set(old_currfig,'CurrentAxes',old_currax);
        end
    end
end

%----------------------------------------------------%
function [leg,warnmsg] = make_legend(ha,argin)

% find and delete existing legend
% leg = find_legend(ha);
% if ~isempty(leg)
%     delete_legend(leg);
% end
% process args
[orient,location,position,children,listen,strings,propargs] = process_inputs(ha,argin);

% set position if empty
if isempty(position)
    position = -1;
end

% set location if empty
if isempty(location)
    if ~is2D(ha)
        location = 'NorthEastOutside';
    else
        location = 'NorthEast';
    end
end
% check prop val args
if ~isempty(propargs)
    check_pv_args(propargs);
end
% get children if empty
auto_children = false;
if isempty(children)
    auto_children = true;
    children = graph2dhelper ('get_legendable_children', ha);
    % if still no children, return empty
    if isempty(children)
        warnmsg = message('MATLAB:legend:PlotEmpty');
        hfig=ancestor(ha,'figure');
        ltogg = uigettool(hfig,'Annotation.InsertLegend');
        if ~isempty(ltogg)
            set(ltogg,'State','off');
        end
        leg = [];
        return;
    end
end
for k=1:length(children)
    child = children(k);
    leginfo = getappdata(child,'LegendLegendInfo');
    if isappdata(child,'LegendLegendInfo') && ...
            (isempty(leginfo) || ~ishandle(leginfo))
        try
            setLegendInfo(handle(child));
        catch ex %#ok<NASGU>
            lis = getappdata(child, 'LegendLegendInfoStruct');
            if ~isempty(lis)
                legendinfo(child, lis{:});
            end
        end
    end
end
% fill in strings if needed
[children,strings,warnmsg] = check_legend_strings(children,strings,auto_children);
% create legend
lh=scribe.legend(ha,orient,location,position,children,listen,strings,propargs{:});
% convert to double
leg=double(lh);

% Inform basic fitting that legend is ready
send(lh, 'LegendConstructorDone', handle.EventData(handle(lh), 'LegendConstructorDone'));

%----------------------------------------------------%
function delete_legend(leg)

if ~isempty(leg) && ishandle(leg) && ~strcmpi(get(leg,'beingdeleted'),'on')
    legh = handle(leg);
    delete(legh);
end

%----------------------------------------------------%
function leg = find_legend(ha)

% Using the "LegendPeerHandle" appdata, we will find the legend peered to
% the current axes. This handle may be invalid due to copy/paste effects.
% In this case, the appdata will be reset.
leg = [];
if isempty(ha) || ~ishandle(ha)
    return;
end
if ~isappdata(double(ha),'LegendPeerHandle')
    return;
end
leg = getappdata(double(ha),'LegendPeerHandle');
if ~ishandle(leg) || ~isequal(get(leg,'Axes'),handle(ha))
    % Reset the "LegendPeerHandle" appdata
    rmappdata(double(ha),'LegendPeerHandle');
    leg = [];
end

%-----------------------------------------------------%
function [leg,hobjs] = find_legend_labelhandles(ha)

leg = find_legend(ha);
hobjs = [];
if ~isempty(leg)
    legh = handle(leg);
    hobjs = [double(legh.itemText)' double(legh.itemTokens)']';
end

%-----------------------------------------------------%
function [leg,hobjs,outH,outM] = find_legend_info(ha)

[leg,hobjs] = find_legend_labelhandles(ha);
outH = [];
outM = [];
if ~isempty(leg)
    legh = handle(leg);
    outH = double(legh.plotchildren);
    outM = legh.String(:).';
end

%----------------------------------------------------%
function tf=islegend(ax)

if length(ax) ~= 1 || ~ishandle(ax)
    tf=false;
else
    tf=isa(handle(ax),'scribe.legend');
end

%----------------------------------------------------%
function [orient,location,position,children,listen,strings,propargs] = process_inputs(ax,argin)

orient='vertical'; location='';
position=[];
children = []; strings = {}; propargs = {};
listen = false;

nargs = length(argin);
if nargs==0
    return;
end

if ischar(argin{1}) && strcmpi(argin{1},'-DynamicLegend')
    listen = true;
    argin(1) = [];
    nargs = nargs-1;
    if nargs==0
        return;
    end
end

% Get location strings long and short form. The short form is the
% long form without any of the lower case characters.
locations = findtype('LegendLocationPreset');
if isempty(locations)
    % explicitly load UDD class and get again
    pkg = findpackage('scribe');
    findclass(pkg,'legend');
    locations = findtype('LegendLocationPreset');
end
locations = locations.Strings;
locationAbbrevs = cell(length(locations),1);
for k=1:length(locations)
    str = locations{k};
    locationAbbrevs{k} = str(str>='A' & str<='Z');
end

% Loop over inputs and determine strings, handles and options
n = 1;
foundAllStrings = false;
while n <= nargs
    if ischar(argin{n})
        if strcmpi(argin{n},'orientation')
            if (n < nargs) && ...
                    ischar(argin{n+1}) && ...
                    ((strncmpi(argin{n+1},'hor',3)) || ...
                    (strncmpi(argin{n+1},'ver',3)))
                % found 'Orientation',ORIENT
                if strncmpi(argin{n+1},'hor',3)
                    orient = 'horizontal';
                else
                    orient = 'vertical';
                end
                n = n + 1; % skip 'Orientation'
            else
                error(message('MATLAB:legend:UnknownParameterOrientation'));
            end
        elseif strcmpi(argin{n},'location')
            if (n < nargs) && ...
                    isnumeric(argin{n+1}) && (length(argin{n+1})==4)
                % found 'Location',POS
                position = argin{n+1};
                location = 'none';
            elseif (n < nargs) && ...
                    ischar(argin{n+1}) && ...
                    (any(strcmpi(argin{n+1}, locations)) || ...
                    any(strcmpi(argin{n+1}, locationAbbrevs)))
                % found 'Location',LOC
                location = argin{n+1};
                % look up the long form location string if needed
                abbrev = find(strcmpi(location, locationAbbrevs));
                if ~isempty(abbrev)
                    location = locations{abbrev};
                end
            else
                error(message('MATLAB:legend:UnknownParameterLocation'));
            end
            n = n + 1; % skip 'Location'
        elseif foundAllStrings && (n < nargs)
            propargs = {propargs{:}, argin{n:n+1}};
            n = n + 1;
        else
            % found a string for legend entry
            strings{end+1} = argin{n}; % single item string
        end
    elseif isnumeric(argin{n}) && length(argin{n})==1 && ...
            mod(argin{n},1)==0
        % a whole number so a numeric location
        % the number might coincidentally be a figure handle, but a figure
        % would never be an input
        location = get_location_from_numeric(argin{n});
    elseif isnumeric(argin{n}) && length(argin{n})==4 && ...
            (n > 1 || ~all(ishandle(argin{n})))
        % to use position vector either it must not be the first argument,
        % or if it is, then the values must not all be handles - in which
        % case the argument will be considered to be the plot children
        % This is an undocumented API for backwards compatibility with
        % Basic Fitting.
        position = argin{n};
        fig = ancestor(ax,'figure');
        position = hgconvertunits(fig,position,'points','normalized', fig);
        center = position(1:2)+position(3:4)/2;
        % .001 is a small number so that legend will resize to fit and centered
        position = [center-.001 0.001 0.001];
        location = 'none';
    elseif iscell(argin{n})
        % found cell array of strings for legend entries
        if ~iscellstr(argin{n})
            error(message('MATLAB:legend:InvalidCellParameter'));
        end
        strings = argin{n};
        foundAllStrings = true;
    elseif n==1 && all(ishandle(argin{n}))
        % found handles to put in legend
        children=argin{n}';
    else
        error(message('MATLAB:legend:UnknownParameter'));
    end
    n = n + 1;
end
strings = strings(:).';

%----------------------------------------------------------------%
function location=get_location_from_numeric(n)

location = [];
%       0 = Automatic "best" placement (least conflict with data)
%       1 = Upper right-hand corner (default)
%       2 = Upper left-hand corner
%       3 = Lower left-hand corner
%       4 = Lower right-hand corner
%      -1 = To the right of the plot
switch n
    case -1
        location = 'NorthEastOutside';
    case 0
        location = 'Best';
    case 1
        location = 'NorthEast';
    case 2
        location = 'NorthWest';
    case 3
        location = 'SouthWest';
    case 4
        location = 'SouthEast';
end

%----------------------------------------------------------------%
% args must be an even number of string,value pairs.
function check_pv_args(args)

n=length(args);
% check that every p is a property
for i=1:2:n
    if ~isprop('scribe','legend',args{i})
        error(message('MATLAB:legend:UnknownProperty', args{ i }));
    elseif strcmpi(args{i},'Parent')
        if ~isa(handle(args{i+1}),'hg.figure') && ~isa(handle(args{i+1}),'hg.uipanel')
            error(message('MATLAB:legend:InvalidParent', get(args{i+1},'Type')));
        end
    end
end

%----------------------------------------------------------------%
function [ch,str,msg]=check_legend_strings(ch,str,auto_children)

msg = [];
% expand strings if possible
if (length(ch) ~= 1) && (length(str) == 1) && (size(str{1},1) > 1)
    str = cellstr(str{1});
end
% if empty, create strings
if isempty(str)
    if auto_children && length(ch) > 50,
        % only automatically add first 50 to cut down on huge lists
        ch = ch(1:50);
    end
    for k=1:length(ch)
        if isprop(ch(k),'DisplayName') &&...
                ~isempty(get(ch(k),'DisplayName'))
            str{k} = get(ch(k),'DisplayName');
        else
            str{k} = ['data',num2str(k)];
        end
    end
else
    % trim children or strings
    if length(str) ~= length(ch)
        if ~auto_children || length(str) > length(ch)
            msg = message('MATLAB:legend:IgnoringExtraEntries');
        end
        m = min(length(str),length(ch));
        ch = ch(1:m);
        str = str(1:m);
    end
    for k=1:length(ch)
        if isprop(ch(k),'DisplayName')
            set(ch(k),'DisplayName',str{k});
        end
    end
end
str = deblank(str);


