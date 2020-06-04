classdef numericInputButton

    properties (Access = private)
        defaultClassOpts
    end

    properties
        panel
        defaultValue
        checkerFunction
        defaultString
        uicontrol
    end

    methods

        function obj = numericInputButton(panel, defaultValue, checkerFunction, varargin)
            %function obj = numericInputButton(panel, defaultValue, checkerFunction, varargin)
            %
            % Creates an interactive input button within a panel.
            % The input button has a default value and a checkerFunctionction that restores
            % the default value if input is not validated by the checkerFunctionction.
            %
            % Inputs:
            %
            % panel - the panel to add the button
            % defaultValue - the default value for the button
            % checkerFucntion - the validation function for the value
            % varargin - Options for uicontrol.
            %
            if nargin < 1
                panel = uipanel();
            end

            if nargin < 2
                defaultValue = 1;
            end

            if nargin < 3
                checkerFunction = @(x)(x);
            end

            obj.panel = panel;
            obj.defaultValue = defaultValue;
            obj.checkerFunction = checkerFunction;

            obj.defaultString = num2str(obj.defaultValue);
            obj.defaultClassOpts = {'Style', 'edit', 'Value', obj.defaultValue, 'String', obj.defaultString};
            obj.uicontrol = uicontrol(panel, obj.defaultClassOpts{:},varargin{:});
            %reference Callback after init since matlab do not support pointers
            obj.uicontrol.Callback = @obj.InputCallback;
        end

            function InputCallback(obj, ~, ~)
            % A custom callback on the 'edit' uicontrol type so we
            % can handle easily handle validation at input time.
            try
                value = str2double(obj.uicontrol.String);
            catch
                obj.uicontrol.String = obj.defaultString;
                return
            end

            if obj.checkerFunction(value)
                obj.uicontrol.Value = str2double(obj.uicontrol.String);
            else
                obj.uicontrol.String = obj.defaultString;
            end
        end

    end

end
