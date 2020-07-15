classdef spikeWindow < handle

    properties (Constant)
        panelMargin = 0.01;
        buttonMargin = 0.01;
        buttonHorSize = 0.15;
        methodHorSize = 0.65;
        previewHorSize = 0.1;
        bottomStripHeight = 0.1;
        okSize = 0.05;
        cancelSize = 0.05;
        windowOpts = {'Name', 'imosTimeSeriesSpikeQC', 'Visible', 'on', 'MenuBar', 'none', 'Resize', 'on', 'NumberTitle', 'off', 'WindowStyle', 'Modal','Units','normalized','Position',[0.25,0.1,0.5,0.8]};
    end

    properties (Access = private)
        default_ticked_boxes(:, 1) containers.Map = containers.Map({'TEMP', 'PSAL', 'CNDC'}, {1, 1, 1});
    end

    properties (Access = public)
        sample_data(1, 1) struct
        varnames(1, :) cell
        opts_file(1, :) char
        has_burst(1, 1) logical
        nvars(1, 1) double
        spike_classifiers(:, 1) containers.Map
        instrument_name(1, :) char
        buttonHeight(1, 1) double

        ui_window%(1,1) matlab.ui.Figure;
        ui_panel%(1,1) matlab.ui.container.Panel;

        panel_opts(1, :) cell;
        ui_tickboxes(1, :) cell;
        ui_popupmenus(1, :) cell;
        ui_previewbuttons(1, :) cell;
        ui_okbutton(1, 1) matlab.ui.control.UIControl;
        ui_cancelbutton(1, 1) matlab.ui.control.UIControl;

        UserData(1, 1) struct;
    end

    methods

        function obj = spikeWindow(sample_data, varnames, opts_file, has_burst)
            obj.sample_data = sample_data;
            obj.varnames = varnames;
            obj.opts_file = opts_file;
            obj.has_burst = has_burst;
            obj.nvars = length(obj.varnames);

            obj.spike_classifiers = loadSpikeClassifiers(obj.opts_file, obj.has_burst);

            try
                obj.instrument_name = [obj.sample_data.meta.instrument_make ':' obj.sample_data.meta.instrument_model];
            catch
                obj.instrument_name = '';
            end

            obj.buttonHeight = (1 - obj.bottomStripHeight - (obj.nvars + 1) * obj.panelMargin) / obj.nvars;

            obj.init_uiwindow();
            obj.init_panel(obj.instrument_name);
            obj.init_cancelbutton();
            obj.init_okbutton();
            obj.init_tickboxes();
            obj.init_popupmenus();
            obj.init_previewboxes();
        end

        function init_uiwindow(obj)
            obj.ui_window = figure(obj.windowOpts{:});
        end

        function init_panel(obj, instrument)
            obj.panel_opts = {'Parent', obj.ui_window, 'title', sprintf('%s - select variables/methods for Spike detection', instrument), 'Units', 'normalized', 'Position', [obj.panelMargin, obj.cancelSize, 1 - obj.panelMargin * 2, 1 - obj.cancelSize - obj.panelMargin]};
            obj.ui_panel = uipanel(obj.panel_opts{:});
        end

        function pos = move_pos_down(obj, pos)
            pos(2) = pos(2) - obj.buttonHeight - obj.buttonMargin;
        end

        function init_tickboxes(obj)
            pos = [obj.buttonMargin, 1 - obj.buttonMargin - obj.buttonHeight, obj.buttonHorSize, obj.buttonHeight];

            for n = 1:obj.nvars
                varname = obj.varnames{n};

                try
                    obj.ui_tickboxes{n} = obj.new_tickbox(varname, obj.default_ticked_boxes(varname), pos);
                catch
                    obj.ui_tickboxes{n} = obj.new_tickbox(varname, 0, pos);
                end

                pos = obj.move_pos_down(pos);
            end

        end

        function box = new_tickbox(obj, name, value, pos)
            value = logical(value);
            opts = {'Parent', obj.ui_panel, 'Style', 'checkbox', 'String', name, 'Value', value, 'Units', 'normalized', 'Position', pos};
            box = uicontrol(opts{:});
        end

        function init_popupmenus(obj)
            pos = [2 * obj.buttonMargin + obj.buttonHorSize, 1 - obj.buttonMargin - obj.buttonHeight, obj.methodHorSize, obj.buttonHeight];

            for n = 1:obj.nvars
                obj.ui_popupmenus{n} = obj.new_popupmenu(obj.spike_classifiers.keys(), pos);
                pos = obj.move_pos_down(pos);
            end

        end

        function popupmenu = new_popupmenu(obj, named_options, pos)
            opts = {'parent', obj.ui_panel, 'Style', 'popupmenu', 'String', named_options, 'Units', 'normalized', 'Position', pos, 'Callback', @menu_selection, 'UserData', named_options{1}};
            popupmenu = uicontrol(opts{:});

            function menu_selection(src, ~)
                src.UserData = src.String{src.Value};
            end

        end

        function init_previewboxes(obj)
            pos = [3 * obj.buttonMargin + obj.buttonHorSize + obj.methodHorSize, 1 - obj.buttonMargin - obj.buttonHeight, obj.previewHorSize, obj.buttonHeight];

            for n = 1:obj.nvars
                obj.ui_previewbuttons{n} = obj.new_previewbutton(pos, n);
                pos = obj.move_pos_down(pos);
            end

        end

        function previewbutton = new_previewbutton(obj, pos, n)
            opts = {'parent', obj.ui_panel, 'style', 'pushbutton', 'String', 'Preview', 'CallBack', @select_and_preview, 'Units', 'normalized', 'Position', pos, 'UserData', []};
            previewbutton = uicontrol(opts{:});

            function select_and_preview(src, ~)
                varname = obj.ui_tickboxes{n}.String;
                varid = getVar(obj.sample_data.variables,varname);
                classifier_name = obj.ui_popupmenus{n}.UserData;
                classifier_struct = obj.spike_classifiers(classifier_name);
                opts = {obj.sample_data.variables{varid}, classifier_name, classifier_struct};
                preview = previewWindow(opts{:});
                uiwait(preview.ui_window);

                if ~isempty(preview.UserData)
                    obj.ui_tickboxes{n}.Value = 1;
                    src.UserData = preview.UserData;
                end

            end

        end

        function init_cancelbutton(obj)
            opts = {'parent', obj.ui_window, 'style', 'pushbutton', 'String', 'Abort', 'CallBack', @obj.close_window, 'Units', 'normalized', 'Position', [0, 0, obj.cancelSize, obj.cancelSize]};
            obj.ui_cancelbutton = uicontrol(opts{:});
        end

        function init_okbutton(obj)
            opts = {'parent', obj.ui_window, 'style', 'pushbutton', 'String', 'OK', 'CallBack', @obj.finalise, 'Units', 'normalized', 'Position', [1 - obj.okSize, 0, obj.okSize, obj.okSize]};
            obj.ui_okbutton = uicontrol(opts{:});
        end

        function close_window(obj, ~, ~)
            close(obj.ui_window);
        end

        function finalise(obj, ~, ~)

            for n = 1:obj.nvars
                varname = obj.varnames{n};
                var_not_selected = ~obj.ui_tickboxes{n}.Value;

                if var_not_selected
                    continue
                end

                user_result = obj.ui_previewbuttons{n}.UserData;
                no_preview = isa(user_result,'double');
                aborted_window = isa(user_result,'struct') && isempty(fieldnames(user_result));
                use_default = no_preview || aborted_window;

                if use_default
                    spike_methods = loadSpikeClassifiers(obj.opts_file, obj.has_burst);
                    selected_method = obj.ui_popupmenus{n}.UserData;
                    obj.UserData.(varname) = spike_methods(selected_method);
                    obj.UserData.(varname).spikes = [];
                else
                    obj.UserData.(varname) = obj.ui_previewbuttons{n}.UserData;
                end

            end

            obj.close_window();
        end

    end

end
