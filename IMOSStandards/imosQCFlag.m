function [ flag desc set_desc ] = imosQCFlag( qc_class, qc_set )
%IMOSQCFLAG Returns an appropriate QC flag value (String) for the given 
% qc_class (String), using the given qc_set (integer).
%
% The value returned by this function is the appropriate QC flag value to use
% for flagging data when using the given QC set. The QC sets, and valid flag 
% values for each, are maintained in the file 'imosQCSets.txt' which is stored 
% in the same directory as this m-file.
%
% Inputs:
%
%   qc_class - must be one of the (case insensitive) strings listed in the 
%              imosQCSets.txt file. If it is not equal to one of these strings, 
%              the flag and desc return values will be empty.
%
%   qc_set   - must be an integer identifier to one of the supported QC sets. 
%              If it does not map to a supported QC set, it is assumed to be 
%              the first qc set defined in the imosQCSets.txt file.
%
% Outputs:
%   flag     - a String containing the appropriate flag value to use.
%
%   desc     - a String containing a human readable description of what the 
%              flag means.
%
%   set_desc - a String containing a human readable description of the QC set.
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

error(nargchk(2, 2, nargin));
if ~ischar(qc_class),  error('qc_class must be a string'); end
if ~isnumeric(qc_set), error('qc_set must be numeric'); end

flag = '';
desc = '';

% open the IMOSQCSets file - it should be 
% in the same directory as this m-file
path = fileparts(which(mfilename));

fid = fopen([path filesep 'imosQCSets.txt']);
if fid == -1, return; end

% read in the QC sets
sets = textscan(fid, '%f%s', 'delimiter', ',', 'commentStyle', '%');

% no set definitions in file
if isempty(sets{1}), return; end

% read in the flag values for each set
flags = textscan(fid, '%f%s%s%s', 'delimiter', ',', 'commentStyle', '%');

% no flag definitions in file
if isempty(flags{1}), return; end

% get the qc set description (or reset the qc set to 1)
qc_set_idx = find(sets{1} == qc_set);
if isempty(qc_set_idx), qc_set_idx = 1; end;

set_desc = sets{2}(qc_set_idx);
set_desc = set_desc{1};

% find a flag entry with matching qc_set and qc_class values
lines = find(flags{1} == qc_set);
for k=1:length(lines)
  
  classes = flags{4}{lines(k)};
  
  % dirty hack to get around matlab's lack of support for word boundaries
  classes = [' ' classes ' '];
  
  % if this flag matches the class, we've found the flag value to return
  if ~isempty(regexpi(classes, ['\s' qc_class '\s'], 'match'))
    
    flag = flags{2}{lines(k)};
    desc = flags{3}{lines(k)};
    break;
    
  end
end
