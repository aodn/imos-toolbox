function testParsers()
% TESTPARSERS Unit test for parser functions.
%
% Executes every parser, using the data sets contained in the 'sample_data' 
% subdirectory.
%
% The sample data files contained in the 'sample_data' subdirectory must 
% follow this naming convention:
%
%   [instrument_name]_sample_data.[extension]
%
% where:
%
%   instrument_name is the instrument name (e.g. SBE37)
%
%   extension is any file extension (if multiple files for the same instrument
%             exist, with different extensions, only the first will be used).
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

% get a list of all available parsers
parsers = listParsers();

% execute each parser
for k = 1:length(parsers)
  parser = parsers{k};
  
  % get the sample data file
  filename = getDataSet(parser);
  
  % execute the parser function
  parserFunc = getParser(parser);
  
  tic;
  [sam cal] = parserFunc(filename);
  time = toc;
  disp([parser 'Parse passed with ' filename ...
       ' (num samples ' int2str(length(sam.dimensions.time)) ...
        ', time ' num2str(time) ' secs)']);
  
end

function filename = getDataSet( inst_name )
%GETDATASET Returns the name of the data set file for the given instrument
%name.
%
% Searches the sample_data subdirectory for a data set to use with the parser
% for the given instrument.
%

filename = '';

% get the location of the sample datasets
path = fileparts(which(mfilename));

% get a list of all datasets
datasets = dir([path filesep 'sample_data']);

for set = datasets'

  tkn = regexp(set.name, ['^' inst_name '_sample_data\..*$'], 'match');
  
  if ~isempty(tkn)
    
    filename = [path filesep 'sample_data' filesep tkn{1}];
        
    break;
  end
end
