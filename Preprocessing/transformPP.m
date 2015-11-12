function sample_data = transformPP( sample_data, qcLevel, auto )
%TRANSFORMPP Prompts the user to select from a list of transformation 
% functions for the variables in the given data sets.
%
% A transformation function is simply a function which performs some 
% arbitrary transformation on a vector/matrix of data.
%
% The motivation for this function is for instruments such as the SBE19, 
% which provide a number of analogue channels into which arbitrary sensors 
% can be plugged. These channels may appear in the resulting data set as 
% raw voltages. This function gives the user the option to transform such 
% raw voltage data into a more appropriate representation. Transformation
% functions are contained in the Preprocessing/Transform/ subdirectory. 
% These functions must have the following signature:
%
%   function [data, name, comment] = xxxTransform.m(sample_data, varIdx)
%
% where:
%   - sample_data - struct containing the entire data set
%   - varIdx      - index into sample_data.variables, the variable which is
%                   to be transformed
%   - data        - vector/matrix, the transformed data
%   - name        - new variable name, if it has changed
%   - comment     - variable comment
%
% The user's most recent selections for each variable (e.g. 'VOLT_3' may 
% always be a fluorometer) are stored in Preprocessing/transformPP.txt.
%
% Inputs:
%   sample_data - cell array of sample_data structs.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%   auto        - logical, run pre-processing in batch mode.
%
% Outputs:
%   sample_data - cell array of sample_data structs.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
  narginchk(2,3);

  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), return;                                    end
  
  % auto logical in input to enable running under batch processing
  if nargin<3, auto=false; end
  
  % no modification of data is performed on the raw FV00 dataset except
  % local time to UTC conversion
  if strcmpi(qcLevel, 'raw'), return; end
  
  % generate descriptions for each data set
  descs = {};
  for k = 1:length(sample_data)
    descs{k} = genSampleDataDesc(sample_data{k});
  end
  
  transformFile = ['Preprocessing' filesep 'transformPP.txt'];
  
  [defaultTransformNames, ...
   defaultTransformValues] = listProperties(transformFile);
  allTransforms            = ['No transform' listTransformations()];
  
  % matrix of indices into allTransforms, the transform
  % routines for each variable of each data set
  transformations = [];
  
  if ~auto
      % dialog figure
      f = figure(...
          'Name',        'Transform',...
          'Visible',     'off',...
          'MenuBar',     'none',...
          'Resize',      'off',...
          'WindowStyle', 'modal',...
          'NumberTitle', 'off'...
          );
      
      % panel which contains data set tabs
      tabPanel = uipanel(...
          'Parent',     f,...
          'BorderType', 'none'...
          );
      
      % ok/cancel buttons
      cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
      confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
      
      % use normalized units for positioning
      set(f,             'Units', 'normalized');
      set(cancelButton,  'Units', 'normalized');
      set(confirmButton, 'Units', 'normalized');
      set(tabPanel,      'Units', 'normalized');
      
      % position widgets
      set(f,             'Position', [0.25, 0.25, 0.5,  0.5]);
      set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.1]);
      set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.1]);
      set(tabPanel,      'Position', [0.0,  0.1,  1.0,  0.9]);
      
      % reset back to pixels
      set(f,             'Units', 'pixels');
      set(cancelButton,  'Units', 'pixels');
      set(confirmButton, 'Units', 'pixels');
      set(tabPanel,      'Units', 'pixels');
      
      % create a panel for each data set
      setPanels = [];
      for k = 1:length(sample_data)
          
          setPanels(k) = uipanel('BorderType', 'none','UserData', k);
      end
      
      % put the panels into a tabbed pane
      tabbedPane(tabPanel, setPanels, descs, false);
      
      % populate the data set panels
      for k = 1:length(sample_data)
          
          sam = sample_data{k};
          
          nVars = length(sam.variables);
          rh    = 0.95 / (nVars + 1);
          
          % column headers
          varHeaderLabel = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Variable', 'FontWeight', 'bold');
          tfmHeaderLabel = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
              'String', 'Transform', 'FontWeight', 'bold');
          
          % position headers
          set(varHeaderLabel, 'Units', 'normalized');
          set(tfmHeaderLabel, 'Units', 'normalized');
          
          set(varHeaderLabel, 'Position', [0.0,  0.95 - rh, 0.5, rh]);
          set(tfmHeaderLabel, 'Position', [0.5,  0.95 - rh, 0.5, rh]);
          
          set(varHeaderLabel, 'Units', 'pixels');
          set(tfmHeaderLabel, 'Units', 'pixels');
          
          % column values (one row for each variable)
          for m = 1:nVars
              
              v    = sam.variables{m};
              tIdx = find(ismember(defaultTransformNames, v.name));
              
              if isempty(tIdx), transformations(k,m) = 1;
              else              transformations(k,m) = find(ismember(...
                      allTransforms, defaultTransformValues{tIdx}));
              end
              
              varLabel = uicontrol('Parent', setPanels(k), 'Style', 'text', ...
                  'String', v.name);
              tfmMenu  = uicontrol('Parent', setPanels(k), 'Style', 'popupmenu', ...
                  'String', allTransforms, ...
                  'Value', transformations(k,m));
              
              % alternate background colour for each row
              if mod(m, 2) ~= 0
                  color = get(varLabel, 'BackgroundColor');
                  color = color - 0.05;
                  
                  set(varLabel, 'BackgroundColor', color);
                  set(tfmMenu,  'BackgroundColor', color);
              end
              
              % position column values
              set(varLabel, 'Units', 'normalized');
              set(tfmMenu,  'Units', 'normalized');
              
              set(varLabel, 'Position', [0.0, 0.95 - (rh*(m+1)),  0.5, rh]);
              set(tfmMenu,  'Position', [0.5, 0.95 - (rh*(m+1)),  0.5, rh]);
              
              set(varLabel, 'Units', 'pixels');
              set(tfmMenu,  'Units', 'pixels');
              
              set(tfmMenu, 'Callback', @menuCallback, 'UserData', [k m]);
          end
      end
      
      set(f,             'WindowKeyPressFcn', @keyPressCallback);
      set(f,             'CloseRequestFcn',   @cancelButtonCallback);
      set(cancelButton,  'Callback',          @cancelButtonCallback);
      set(confirmButton, 'Callback',          @confirmButtonCallback);
      
      set(f, 'Visible', 'on');
      uiwait(f);
  else
      for k = 1:length(sample_data)
          
          sam = sample_data{k};
          nVars = length(sam.variables);
          
          for m = 1:nVars
              
              v    = sam.variables{m};
              tIdx = find(ismember(defaultTransformNames, v.name));
              
              if isempty(tIdx), transformations(k,m) = 1;
              else              transformations(k,m) = find(ismember(...
                      allTransforms, defaultTransformValues{tIdx}));
              end
          end
      end
  end
  
  if isempty(transformations), return; end
  
  % apply the transformations, and save defaults
  for k = 1:size(transformations,1)
    
    sam = sample_data{k};
    
    for m = 1:size(transformations,2)
      
      % if no transform for this variable, 
      % save as the default, and continue
      if transformations(k,m) == 1
        
        delProperty(sam.variables{m}.name, transformFile);
        continue; 
      end
      
      % get the transformation function
      tfmName = allTransforms{transformations(k,m)};
      tfmFunc = str2func(tfmName);
      
      % apply the transformation
      [data, name, comment, history] = tfmFunc(sam, m);
      dimensions = sam.variables{m}.dimensions;
      
      % update new default for this variable
      writeProperty(sam.variables{m}.name, tfmName, transformFile);
      
      if isfield(sam.variables{m}, 'coordinates')
          coordinates = sam.variables{m}.coordinates;
      else
          coordinates = '';
      end
      
      % replace the old variable with the new variable
      sam = addVar(sam, name, data, dimensions, comment, coordinates);
      sam.variables{m} = sam.variables{end};
      sam.variables(end) = [];
      sam.history = history;
    end
    
    sample_data{k} = sam;
  end
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelButtonCallback/confirmButtonCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelButtonCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmButtonCallback(source,ev); 
    end
  end

  function cancelButtonCallback(source,ev)
  %CANCELBUTTONCALLBACK Discards user input, and closes the dialog.
  % 
    transformations = [];
    delete(f);
  end

  function confirmButtonCallback(source,ev)
  %CONFIRMBUTTONCALLBACK Closes the dialog.
  % 
    delete(f);
  end

  function menuCallback(source,ev)
  %MENUCALLBACK Called when any of the transformation menus change. Saves
  % the new selection to the transformations matrix.
    
    ud  = get(source, 'UserData');
    val = get(source, 'Value');
    
    setIdx = ud(1);
    varIdx = ud(2);
    
    transformations(setIdx,varIdx) = val;
  end
end
