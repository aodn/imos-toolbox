function [redirect,mapfile,topic] = checkForDemoRedirect(html_file)
% Internal use only.

%   Copyright 2012 The MathWorks, Inc.

% Defaults.
redirect = false;
mapfile = '';
topic = '';

% WEB called with no arguments?
if isempty(html_file)
    return
end

% Under matlab/toolbox? (Use FILEPARTS to align fileseps).
[htmlDir,topic] = fileparts(fullfile(html_file));
toolbox = fullfile(matlabroot,'toolbox');
if ~strncmp(toolbox,htmlDir,numel(toolbox))
    return
end

% In an "html" directory?
relDir = strrep(htmlDir(numel(toolbox)+2:end),'\','/');
if isempty(regexp(relDir,'/html$','once')) 
    return
end
    
% In foodemos (or foodemo for wavedemo) or examples?
if isempty(regexp(relDir,'demos?/','once')) && ...
   isempty(regexp(relDir,'/examples/','once'))
    return
end

% Acorresponding map file?
book = mapDirToBook(relDir);
mapfile = fullfile(docroot,book,'examples',[book '_examples.map']);
if numel(dir(mapfile)) ~= 1
    return
end

% Contains topic?
topicMap = com.mathworks.mlwidgets.help.CSHelpTopicMap(mapfile);
if isempty(topicMap.mapID(topic))
    return
end

% Then redirect!
redirect = true;

end

%--------------------------------------------------------------------------
function book = mapDirToBook(relDir)

dc = @(d)strncmp(relDir,[d '/'],numel(d)+1);
if dc('aero')
    book = 'aerotbx';
elseif dc('shared/eda') || dc('shared/tlmgenerator')
    book = 'hdlverifier';
elseif dc('globaloptim')
    book = 'gads';
elseif dc('idelink') || dc('target')
    book = 'rtw';
elseif dc('simulink/fixedandfloat')
    book = 'fixpoint';
elseif dc('physmod')
    book = regexp(relDir,'(?<=/)[^\/]+','match','once');
    if strcmp(book,'sh')
        book = 'hydro';
    end
elseif dc('rtw/targets')
    book = regexp(relDir,'(?<=targets\/)[^\/]+','match','once');
else
    book = regexp(relDir,'[^\/]+','match','once');
end
end
