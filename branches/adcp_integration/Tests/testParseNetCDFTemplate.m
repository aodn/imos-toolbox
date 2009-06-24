function testParseNetCDFTemplate()
%testParseNetCDFTemplate attempts to load all existing NetCDF template files.
%
% Runs through every NetCDF template file in the NetCDF/template subdirectory
% with a test data set, ensuring that the parseNetCDFTemplate function does not 
% fail.
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

  disp(' ');
  disp(['-- ' mfilename ' --']);
  disp(' ');

  % test data
  sam = genTestData(100, {'TEMP', 'CNDC'}, 1, 100, ...
                          [1,1],[100,100],[1,1],[100,100]);

  % get the full path of the template subdirectory
  templateDir = fileparts(which(mfilename));
  templateDir = [templateDir filesep '..' filesep 'NetCDF' filesep 'template'];

  templates = dir(templateDir);

  for t = templates'

    if t.isdir, continue; end

    t = [templateDir filesep t.name];

    disp(['parsing ' t]);

    res = parseNetCDFTemplate(t, sam, 1);
    
    disp('');
    disp(res);
    
    atts = listAtts(t);
    
    for a = atts
      
      a = a{1};
      
      % underscore kludge. stupid matlab
      if a(1) == '_', a = [a(2:end) '_']; end
      
      if ~isfield(res, a)
        error(['field ' a ' is missing from template (' t ')']); 
      end
    end
  end
end

function atts = listAtts(file)
%LISTATTS Lists the names or all the attributes in the given template file.
%
%Reads the given template file, and returns a cell array of strings containing 
%the names of all the attributes that are contained in the file.
%
% Inputs:
%   file - name of template file
%
% Outputs:
%   atts - cell array containing attribute names
%
  atts = {};

  fid = fopen(file);
  if fid == -1, return; end

  line = fgetl(fid);

  while ischar(line)
    
    tkns = regexp(line, '^\s*(.*\S)\s*=', 'tokens');
    if ~isempty(tkns), atts{end+1} = tkns{1}{1}; end
    line = fgetl(fid);
    
  end
  
  fclose(fid);
end
