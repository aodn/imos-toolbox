classdef previewWindow < handle

    properties (Constant)
        limits_opts_func = @imosSpikeClassifiersLimits;

        windowOpts = {'Name', 'imosTimeSeriesSpikeQC::Preview', 'Visible', 'on', 'MenuBar', 'none', 'Resize', 'on', 'NumberTitle', 'off', 'WindowStyle', 'Modal','Units','normalized','Position',[0.1,0.1,.8,.8]};

        panelMargin = 0.025;
        buttonMargin = 0.025;

        topPanelHSize = 0.95;
        topPanelVSize = 0.60;

        topPanelPrevNextHSize = 0.05;
        topPanelPrevNextVSize = 0.1;

        topPanelVarHSize = previewWindow.topPanelPrevNextHSize;
        topPanelVarVSize = previewWindow.topPanelVSize - previewWindow.topPanelPrevNextVSize;

        topPanelFigAxisHSize = previewWindow.topPanelHSize - 2 * previewWindow.topPanelVarHSize;
        topPanelFigAxisVSize = previewWindow.topPanelVSize - previewWindow.topPanelPrevNextVSize;

        topPanelLockHSize = previewWindow.topPanelFigAxisHSize;
        topPanelLockVSize = previewWindow.topPanelPrevNextVSize;

        botPanelHSize = previewWindow.topPanelHSize;

        botPanelLeftValueHSize = previewWindow.topPanelPrevNextHSize;

        botPanelBarTitleHSize = previewWindow.topPanelFigAxisHSize;
        botPanelBarTitleVSize = previewWindow.buttonMargin;

        botPanelBarHSize = previewWindow.topPanelFigAxisHSize;

        okSize = 0.05;
        cancelSize = 0.05;
    end

    properties (Access = public)
        botButtonHeight
        botPanelVSize
        botPanelLeftValueVSize
        botPanelBarVSize

        is_data_burst = false;
        date_ticks_number = 10;

        postqc_data
        varname
        xdata
        ydata
        valid_burst_range
        spikes

        classifier_name
        classifier_limits
        classifier_fun
        classifier_arg_names
        classifier_arg_values
        nparams

        ui_window

        ui_top_panel_opts
        ui_top_panel
        ui_top_view = struct();

        ui_bot_panel_opts
        ui_bot_panel
        ui_bot_leftvalue_boxes = {};
        ui_bot_sliders_titles = {};
        ui_bot_sliders = {};
        ui_bot_setdefault_boxes = {};

        ui_cancelbutton
        ui_okbutton

        UserData = struct();

    end

    methods

        function obj = previewWindow(postqc_data, classifier_name, classifier_struct, varargin)
            %function obj = previewWindow(postqc_data, classifier_name, classifier_struct, varargin)
            %
            % Creates the spike preview window.
            % When the user finishes (ok button), the UserData property is set.
            %
            % Inputs:
            %
            % postqc_data - the toolbox struct with data
            % classifier_name - the SpikeClassifier method name
            % classifier_struct - the SpikeClassifier struct
            %
            % Outputs:
            %
            % The class.
            %
            % Properties:
            %
            % UserData - struct with options selected. May be empty if no selection is done.
            %         .args - the argument values selected/used for the spikeClassifier
            %         .spikes - the spikes index locations
            %
            %
            % author: hugo.oliveira@utas.edu.au
            %

            obj.postqc_data = postqc_data;
            obj.varname = postqc_data.name;
            obj.ydata = postqc_data.data;
            obj.xdata = postqc_data.time;

            % set bursts info if avail.
            if isfield(obj.postqc_data, 'valid_burst_range')
                obj.is_data_burst = true;
                obj.valid_burst_range = obj.postqc_data.valid_burst_range;
            end

            % load SpikeQC options
            obj.classifier_name = classifier_name;
            obj.classifier_fun = classifier_struct.fun;
            obj.classifier_arg_names = classifier_struct.opts;
            obj.classifier_arg_values = classifier_struct.args;

            limit_struct = obj.limits_opts_func(length(obj.ydata));
            obj.classifier_limits = struct();

            for k = 1:length(obj.classifier_arg_names)
                lname = obj.classifier_arg_names{k};
                obj.classifier_limits.(lname) = limit_struct.(lname);
            end

            obj.nparams = length(obj.classifier_arg_names);

            %compute the parameter buttons sizes based on input

            obj.botPanelVSize = 1 - obj.topPanelVSize - 2 * obj.panelMargin;

            obj.botPanelLeftValueVSize = 1 / obj.nparams - 2 * obj.buttonMargin;

            obj.botPanelBarVSize = obj.botPanelLeftValueVSize / 2;

            %draw
            obj.init_uiwindow();
            obj.init_botpanel();
            obj.init_bot_leftvalue_boxes();
            obj.init_bot_sliders_titles();
            obj.init_bot_sliders();
            obj.init_toppanel();
            obj.init_cancelbutton();
            obj.init_okbutton();
            obj.init_top_plot();

        end

        function init_uiwindow(obj)
            obj.ui_window = figure(obj.windowOpts{:});
        end

        function init_botpanel(obj)
            pos = [obj.panelMargin, obj.cancelSize, obj.botPanelHSize, obj.botPanelVSize];
            obj.ui_bot_panel_opts = {'title', 'Parameters', 'Units', 'normalized', 'Position', pos};
            obj.ui_bot_panel = uipanel(obj.ui_window, obj.ui_bot_panel_opts{:});
        end

        function init_bot_leftvalue_boxes(obj)
            pos = [obj.panelMargin, 1 - obj.panelMargin - obj.botPanelLeftValueVSize, obj.botPanelLeftValueHSize, obj.botPanelLeftValueVSize];

            for n = 1:obj.nparams

                if isa(obj.classifier_arg_values{n}, 'function_handle')
                    obj.ui_bot_leftvalue_boxes{n} = new_bot_leftvalue_text(obj, pos, n);
                else
                    obj.ui_bot_leftvalue_boxes{n} = new_bot_leftvalue_box(obj, pos, n);
                end

                pos(2) = pos(2) - obj.botPanelLeftValueVSize - obj.buttonMargin;
            end

        end

        function bot_leftvalue_text = new_bot_leftvalue_text(obj, pos, n)
            [name, ~, ~, ~, ~, helpmsg] = obj.load_parameter_info(n);
            available_funcs = obj.classifier_limits.(name).available;
            available_opts = cell(1, length(available_funcs));

            for k = 1:length(available_funcs)
                available_opts{k} = func2str(available_funcs{k});
            end

            sname = available_opts{1};
            pos(2) = pos(2) - obj.botPanelLeftValueVSize * 0.25 + obj.buttonMargin;
            opts = {'Parent', obj.ui_bot_panel, 'Style', 'text', 'String', sname, 'Units', 'normalized', 'Position', pos, 'TooltipString', helpmsg};
            bot_leftvalue_text = uicontrol(opts{:});
        end

        function bot_leftvalue_box = new_bot_leftvalue_box(obj, pos, n)
            opts = {'Units', 'normalized', 'Position', pos};
            [~, value, vfun, ~] = obj.load_parameter_info(n);
            laterCallback = @sync_value_to_slider_and_redraw;
            bot_leftvalue_box = numericInputButton(obj.ui_bot_panel, value, vfun, laterCallback, opts{:});

            function sync_value_to_slider_and_redraw(~, ~)
                obj.ui_bot_sliders{n}.Value = obj.ui_bot_leftvalue_boxes{n}.uicontrol.Value;
                obj.redraw()
            end

        end

        function [name, value, vfun, limits, fraclimits, helpmsg] = load_parameter_info(obj, n)

            name = obj.classifier_arg_names{n};
            value = obj.classifier_arg_values{n};
            helpmsg = obj.classifier_limits.(name).help;

            if isfield(obj.classifier_limits.(name), 'available')
                vfun = @(x)(isa(x, 'function_handle'));
                limits = [];
                fraclimits = [];
                return
            end

            lmin = obj.classifier_limits.(name).min;
            lmax = obj.classifier_limits.(name).max;
            limits = [min(lmin, lmax) max(lmin, lmax)];
            helpmsg = obj.classifier_limits.(name).help;

            srange = double(limits(2) - limits(1));

            if islogical(lmin)
                vfun = @(x)(x == true || x == false);
                fraclimits = [1, 1];
            elseif isint(lmin)
                vfun = @(x)(x >= lmin && x <= lmax);
                frange = [(1 + 1e-6) / srange, 0.1];

                if frange(1) > frange(2)
                    fraclimits = [1/srange 1/srange];
                else
                    fraclimits = frange;
                end

            else
                vfun = @(x)(x >= lmin && x <= lmax);
                fraclimits = [1e-3 0.1];
            end

        end

        function init_bot_sliders_titles(obj)
            pos = [2 * obj.panelMargin + obj.botPanelLeftValueHSize, 1 - obj.botPanelBarVSize, obj.botPanelBarHSize, obj.botPanelBarVSize];

            for n = 1:obj.nparams
                name = obj.classifier_arg_names{n};
                helpmsg = obj.classifier_limits.(name).help;
                opts = {'Parent', obj.ui_bot_panel, 'Style', 'text', 'String', name, 'Units', 'normalized', 'Position', pos, 'TooltipString', helpmsg};
                obj.ui_bot_sliders_titles{n} = uicontrol(opts{:});
                pos(2) = pos(2) - obj.botPanelLeftValueVSize - obj.buttonMargin;
            end

        end

        function init_bot_sliders(obj)
            title_offset_scale = 0.75;
            centre_offset_scale = 0.5;
            pos = [2 * obj.panelMargin + obj.botPanelLeftValueHSize, 1 - obj.panelMargin - obj.botPanelLeftValueVSize * title_offset_scale, obj.botPanelBarHSize, obj.botPanelBarVSize];

            for n = 1:obj.nparams

                if isa(obj.classifier_arg_values{n}, 'function_handle')
                    obj.ui_bot_sliders{n} = obj.new_pushbutton(pos, n);
                else
                    obj.ui_bot_sliders{n} = obj.new_slider(pos, n);
                end

                pos(2) = pos(2) - obj.botPanelLeftValueVSize * title_offset_scale - obj.botPanelBarVSize * centre_offset_scale - obj.buttonMargin;
            end

        end

        function pushbutton = new_pushbutton(obj, pos, n)
            [name, ~, ~, ~, ~, helpmsg] = obj.load_parameter_info(n);
            available_funcs = obj.classifier_limits.(name).available;
            available_opts = cell(1, length(available_funcs));

            for k = 1:length(available_funcs)
                available_opts{k} = func2str(available_funcs{k});
            end

            opts = {'Parent', obj.ui_bot_panel, 'Style', 'pushbutton', 'String', available_opts{1}, 'Units', 'normalized', 'Position', pos, 'Callback', @cycle_and_sync, 'UserData', available_funcs{1}, 'TooltipString', helpmsg};
            pushbutton = uicontrol(opts{:});

            function cycle_and_sync(src, ~)
                current = src.String;
                ind = find(contains(available_opts, current));

                if ind + 1 > length(available_opts)
                    ind = 1;
                else
                    ind = ind + 1;
                end

                next = available_opts{ind};
                src.String = next;
                src.UserData = available_funcs{ind};
                obj.ui_bot_leftvalue_boxes{n}.String = next;
                obj.ui_bot_leftvalue_boxes{n}.UserData = available_funcs{ind};
                obj.redraw()
            end

        end

        function slider = new_slider(obj, pos, n)
            [name, value, ~, limits, fraclimits, helpmsg] = obj.load_parameter_info(n);
            opts = {'Parent', obj.ui_bot_panel, 'Style', 'slider', 'Units', 'normalized', 'Position', pos, 'Callback', @convert_and_sync_values};
            other_opts = {'Value', value, 'Min', limits(1), 'Max', limits(2), 'SliderStep', fraclimits, 'Tooltip', name, 'String', name, 'TooltipString', helpmsg, 'UserData', str2func(class(limits))};
            slider = uicontrol(opts{:});

            for k = 1:2:length(other_opts)
                slider.(other_opts{k}) = other_opts{k + 1};
            end

            function convert_and_sync_values(src, ~)
                typefun = src.UserData;
                obj.ui_bot_leftvalue_boxes{n}.uicontrol.String = num2str(typefun(src.Value));
                obj.ui_bot_leftvalue_boxes{n}.uicontrol.Callback();
            end

        end

        function [new_args] = get_user_arguments(obj)
            new_args = cell(1, length(obj.ui_bot_leftvalue_boxes));

            for k = 1:length(new_args)

                try
                    new_args{k} = obj.ui_bot_leftvalue_boxes{k}.uicontrol.Value;
                catch
                    new_args{k} = obj.ui_bot_sliders{k}.UserData;
                end

            end

        end

        function init_toppanel(obj)
            pos = [obj.panelMargin, obj.cancelSize + obj.botPanelVSize, obj.topPanelHSize, obj.topPanelVSize];
            obj.ui_top_panel_opts = {'title', sprintf('SpikeQC Preview for %s using %s', obj.varname, obj.classifier_name), 'Units', 'normalized', 'Position', pos};
            obj.ui_top_panel = uipanel(obj.ui_window, obj.ui_top_panel_opts{:});
        end

        function init_top_plot(obj)
            [obj.ui_top_view.axes_h, obj.ui_top_view.axbuttons_h, obj.ui_top_view.raw_plot_h, obj.ui_top_view.spike_plot_h] = obj.new_top_view();
            %TODO next/prev for spike navigation
            %uicontrol('Style','pushbutton','String','next','Callback',obj.next_spike)
            %uicontrol('Style','pushbutton','String','prev','Callback',obj.prev_spike)
        end

        function [x_spikes, y_spikes] = load_spike_values(obj, varargin)
            x_spikes = [];
            y_spikes = [];

            if obj.is_data_burst
                obj.spikes = obj.classifier_fun(obj.valid_burst_range, obj.ydata, varargin{:});
            else
                obj.spikes = obj.classifier_fun(obj.ydata, varargin{:});
            end

            if ~isempty(obj.spikes)
                x_spikes = obj.xdata(obj.spikes);
                y_spikes = obj.ydata(obj.spikes);
            end

        end

        function [axes_h, axbuttons_h, raw_plot_h, spike_plot_h] = new_top_view(obj)
            xmin = min(obj.xdata);
            xmax = max(obj.xdata);
            ymin = min(obj.ydata);
            ymax = max(obj.ydata);
            xlen = xmax - xmin;
            ylen = ymax - ymin;
            fact = 0.05;
            xlim = [xmin - fact * xlen, xmax + fact * xlen];
            ylim = [ymin - fact * ylen, ymax + fact * ylen];
            z = uicontrol('Style', 'text', 'String', 'Loading...', 'Units', 'normalized', 'Position', [0.5, 0.5, 0.1, 0.1]);
            [x_spikes, y_spikes] = obj.load_spike_values(obj.classifier_arg_values{:});
            z.delete()
            axes_h = axes(obj.ui_top_panel, 'XLimMode', 'manual', 'YLimMode', 'manual');
            axbuttons = {'datacursor', 'pan', 'zoomin', 'zoomout', 'restoreview'};
            axbuttons_h = axtoolbar(axes_h, axbuttons, 'Visible', 'on');

            if obj.is_data_burst
                raw_plot_h{1} = scatter(axes_h, obj.xdata, obj.ydata, [], 'bs');
                raw_plot_h{2} = line(axes_h, 'Xdata', obj.xdata, 'Ydata', obj.ydata, 'Color', 'g', 'LineStyle', '--');
            else
                raw_plot_h{1} = line(axes_h, 'Xdata', obj.xdata, 'Ydata', obj.ydata, 'Color', 'k');
            end

            hold on
            spike_plot_h = scatter(axes_h, x_spikes, y_spikes, [], 'r');
            axes_h.XLim = xlim;
            axes_h.YLim = ylim;
            update_xdateticks(true, struct('Axes', axes_h));
            dcm = datacursormode();
            dcm.UpdateFcn = @update_tooltip;
            pan_h = pan();
            zoom_h = zoom();
            zoom_h.ActionPostCallback = @update_xdateticks; %(~, ~)(datetick(axes_h, 'x', 'dd-mm-yy HH:MM', 'keeplimits')))
            pan_h.ActionPostCallback = @update_xdateticks;
            ratio = 100 * length(x_spikes) / length(obj.xdata);
            title(sprintf('Spike detection ratio %2.4f - nspikes=%i', ratio, length(x_spikes)));

            function [txt] = update_tooltip(~, ev)
                pos = ev.Position;
                tdate = datestr(pos(1));
                tval = num2str(pos(2));
                txt = {['Time: ', tdate], ['Value: ' tval]};
            end

            function update_xdateticks(~, es)
                axes_state = es.Axes;
                window = axes_state.XLim(2) - axes_state.XLim(1);
                over_a_day = window > 1;
                within_a_day = window < 1;
                within_the_hour = window < 1/24;
                within_the_minute = window < 1/1440;

                if over_a_day
                    datetick(axes_state, 'x', 'dd-mm-yy HH:MM', 'keeplimits');
                elseif within_a_day
                    datetick(axes_state, 'x', 'dd HH:MM:SS', 'keeplimits');
                elseif within_the_hour
                    datetick(axes_state, 'x', 'HH:MM:SS', 'keeplimits');
                elseif within_the_minute
                    datetick(axes_state, 'x', 'MM:SS', 'keeplimits');
                end

            end

        end

        function redraw(obj)
            new_args = obj.get_user_arguments();
            obj.ui_top_view.spike_plot_h.delete();
            [x_spikes, y_spikes] = obj.load_spike_values(new_args{:});
            obj.ui_top_view.spike_plot_h = scatter(obj.ui_top_view.axes_h, x_spikes, y_spikes, [], 'r');
            ratio = length(x_spikes) / length(obj.xdata);
            title(sprintf('Spike detection ratio %2.4f - nspikes=%i', ratio, length(x_spikes)));
        end

        function init_cancelbutton(obj)
            pos = [0, 0, obj.cancelSize, obj.cancelSize];
            opts = {'parent', obj.ui_window, 'style', 'pushbutton', 'String', 'Abort', 'CallBack', @obj.close_window, 'Units', 'normalized', 'Position', pos};
            obj.ui_cancelbutton = uicontrol(opts{:});
        end

        function init_okbutton(obj)
            pos = [1 - obj.okSize, 0, obj.okSize, obj.okSize];

            opts = {'parent', obj.ui_window, 'style', 'pushbutton', 'String', 'OK', 'CallBack', @obj.finalise, 'Units', 'normalized', 'Position', pos};
            obj.ui_okbutton = uicontrol(opts{:});
        end

        function close_window(obj, ~, ~)
            close(obj.ui_window);
        end

        function obj = finalise(obj, ~, ~)
            %sync left values
            for k = 1:length(obj.ui_bot_leftvalue_boxes)

                if obj.is_data_burst

                    if isfield(obj.ui_bot_leftvalue_boxes, 'laterCallback')
                        obj.ui_bot_leftvalue_boxes{k}.laterCallback();
                    end

                end

            end

            obj.UserData.fun = obj.classifier_fun;
            obj.UserData.opts = obj.classifier_arg_names;
            obj.UserData.args = obj.get_user_arguments();
            obj.UserData.spikes = obj.spikes;
            obj.close_window();
        end

    end

end
