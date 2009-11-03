function [names values] = listProperties(file, delim)
%LISTPROPERTIES Returns a cell array containing all key value pairs in the
%given file.
%
% This function reads the given property file, and returns all of the key 
% value pairs contained within.
%
% A 'property' file is a file which contains a list of name value pairs,
% separated by a delimiter. If the optional delim parameter is not provided, 
% it is assumed that the file uses '=' as the delimiter.
%
% Inputs:
%
%   file   - Optional. Name of the property file. Must be specified relative 
%            to the IMOS toolbox root. Defaults to 'toolboxProperties.txt'.
%
%   delim  - Optional. Delimiter character/string. Defaults to '='.
%
% Outputs:
%   names  - Cell array containing property names contained in the file.
%   values - Cell array containing property values contained in the file.
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
error(nargchk(0,2,nargin));

if ~exist('delim', 'var'), delim = '=';                     end
if ~exist('file',  'var'), file  = 'toolboxProperties.txt'; end

if ~ischar(delim),       error('delim must be a string'); end
if ~exist(file, 'file'), error('file must be a file');    end

propFilePath = pwd;

% read in all the name=value pairs
fid = fopen([propFilePath filesep file], 'rt');
if fid == -1, error(['could not open ' file]); end

props = textscan(fid, '%s%s', 'Delimiter', delim, 'CommentStyle', '%');

fclose(fid);

names  = props{1};
values = props{2};

names  = cellfun(@strtrim, names,  'UniformOutput', false);
values = cellfun(@strtrim, values, 'UniformOutput', false);
