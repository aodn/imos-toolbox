function [year month day] = datePromptDialog(year,month,day)
%DATEPROMPTDIALOG Prompts the user to enter a date, returns the date value.
%
% Displays a simple dialog which prompts the user to enter a date.
%
% Inputs:
%   year  - the initial year to use (numeric)
%   month - the initial month to use (numeric)
%   day   - the initial day to use (numeric)
%
% Outputs:
%   year  - the selected year, or the same as the input if the user 
%           cancelled the dialog.
%   month - the selected month, or the same as the input if the user 
%           cancelled the dialog.
%   day   - the selected day, or the same as the input if the user 
%           cancelled the dialog.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
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
  % validate input
  error(nargchk(3,3,nargin));

  if ~isnumeric(year)  && ~isscalar(year)
    error('year must be a scalar numeric');  end
  if ~isnumeric(month) && ~isscalar(month)
    error('month must be a scalar numeric'); end
  if ~isnumeric(day)   && ~isscalar(day)
    error('day must be a scalar numeric');   end
  
  if year  < 1950 || year  > 2050, year = 1950; end
  if month < 1    || month > 12,   month = 1;   end
  if day   < 1    || day   > 31,   day = 1;     end

  % save input so we can revert it if the user cancels the dialog
  origYear  = year;
  origMonth = month;
  origDay   = day;

  % dialog figure
  f = figure('Name',        'Enter date', ...
             'Visible',     'off',...
             'MenuBar',     'none',...
             'Resize',      'off',...
             'WindowStyle', 'Modal',...
             'NumberTitle', 'off');
  
  % create widgets
  yearMenu      = uicontrol('Style', 'popupmenu');
  monthMenu     = uicontrol('Style', 'popupmenu');
  dayMenu       = uicontrol('Style', 'popupmenu');
  
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');
  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  
  % set up list ranges
  [currentYear currentMonth currentDay] = datevec(date());
  if year < 1950, yearVals = year:currentYear;
  else            yearVals = 1950:currentYear;
  end
  dayVals = 1:genDayRange(year,month);
  
  monthVals = {
    'Jan','Feb','Mar','Apr','May','Jun',...
    'Jul','Aug','Sep','Oct','Nov','Dec'
  };
  
  set(yearMenu,  'String', yearVals,  'Value', find(yearVals == year));
  set(monthMenu, 'String', monthVals, 'Value', month);
  set(dayMenu,   'String', dayVals,   'Value', day);
  
  % use normalized units
  set(f,             'Units', 'normalized');
  set(yearMenu,      'Units', 'normalized');
  set(monthMenu,     'Units', 'normalized');
  set(dayMenu,       'Units', 'normalized');
  set(cancelButton,  'Units', 'normalized');
  set(confirmButton, 'Units', 'normalized');
  
  % position figure and widgets
  set(f,             'Position', [0.4,  0.46, 0.2,  0.08]);
  set(cancelButton,  'Position', [0.0,  0.0,  0.5,  0.5 ]);
  set(confirmButton, 'Position', [0.5,  0.0,  0.5,  0.5 ]);
  set(yearMenu,      'Position', [0.0,  0.5,  0.33, 0.5 ]);
  set(monthMenu,     'Position', [0.33, 0.5,  0.34, 0.5 ]);
  set(dayMenu,       'Position', [0.67, 0.5,  0.33, 0.5 ]);
  
  % reset back to pixel units
  set(f,             'Units', 'pixels');
  set(yearMenu,      'Units', 'pixels');
  set(monthMenu,     'Units', 'pixels');
  set(dayMenu,       'Units', 'pixels');
  set(cancelButton,  'Units', 'pixels');
  set(confirmButton, 'Units', 'pixels');
  
  % set widget callbacks
  set(f,             'CloseRequestFcn', @cancelCallback);
  set(cancelButton,  'Callback',        @cancelCallback);
  set(confirmButton, 'Callback',        @confirmCallback);
  set(yearMenu,      'Callback',        @yearCallback);
  set(monthMenu,     'Callback',        @monthCallback);
  set(dayMenu,       'Callback',        @dayCallback);
  
  % enable use of return/escape to confirm/cancel dialog
  set(f, 'WindowKeyPressFcn', @keyPressCallback);
  
  set(f, 'Visible', 'on');
  uiwait(f);
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK Allows the user to hit the escape/return keys to 
  % cancel/confirm the dialog respectively.
  
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end
  
  function cancelCallback(source,ev)
  %CANCELCALLBACK Reverts user input, then closes the dialog.
  
    year  = origYear;
    month = origMonth;
    day   = origDay;
    delete(f);
  end

  function confirmCallback(source,ev)
  %CONFIRMCALLBACK Closes the dialog.
  
    delete(f);
  end

  function yearCallback(source,ev)
  %YEARCALLBACK Called when the year value is changed. Saves the value
  % and updates the number of days in the month.
  
    idx  = get(yearMenu, 'Value');
    strs = get(yearMenu, 'String');
    year = str2double(strs(idx,:));
    
    % update the contents of the day menu; if the month is 
    % february and the year changes from a non-leap year to 
    % a leap year or vice versa, the number of days will change    
    set(dayMenu, 'String', 1:genDayRange(year,month));
    
    % matlab is stupid. if the selected date is 29/02, and the 
    % year changes from a leap year to a non-leap year, matlab 
    % is not smart enough to change the selected day so that it 
    % is within the valid range, hence it complains with an error.
    % we avoid this error by rolling back the selected day, if 
    % necessary.
    if isLeapYear(year), return; end
    
    day   = get(dayMenu,   'Value');
    month = get(monthMenu, 'Value');
    if month == 2 && day == 29
      day = day - 1;
      set(dayMenu, 'Value', day);
    end
  end

  function monthCallback(source,ev)
  %MONTHCALLBACK Called when the month value is changed. Saves the value
  % and updates the number of days in the month.
  
    month = get(monthMenu, 'Value');
    set(dayMenu, 'String', 1:genDayRange(year,month));
  end

  function dayCallback(source,ev)
  %DAYCALLBACK Called when the day value is changed. Saves the value.
  
    day = get(dayMenu, 'Value');
  end

  function drange = genDayRange(y,m)
  %GENDAYRANGE Generate a day ranges for the popup menus for the given date.
  % Takes into account different number of days for different months, and
  % leap years. The given month is 1-indexed (i.e. January == 1).
  %    
    switch(m)
      case 1,    drange = 31;
      case 2,    if isLeapYear(year), drange = 29; else drange = 28; end
      case 3,    drange = 31;
      case 4,    drange = 30;
      case 5,    drange = 31;
      case 6,    drange = 30;
      case 7,    drange = 31;
      case 8,    drange = 31;
      case 9,    drange = 30;
      case 10,   drange = 31;
      case 11,   drange = 30;
      case 12,   drange = 31;
      otherwise, drange = 1;
    end
  end

  function leap = isLeapYear(y)
  %Determines whether the given year is a leap year.
  
    % leap years: divisible by 400, or divisible by 4 but not by 100
    leap = (mod(y,400) == 0) || ((mod(y,4) == 0) && (mod(y,100) ~= 0));
  end
end
