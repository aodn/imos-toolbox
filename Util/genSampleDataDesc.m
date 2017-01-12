function desc = genSampleDataDesc( sam, detailLevel )
%GENSAMPLEDATADESC Generates a string description of the given sample_data
% struct.
%
% This function exists so that a uniform sample data description format can
% be used throughout the toolbox.
% 
% Inputs:
%   sam          - struct containing a data set
%   detailLevel  - string either 'full', 'medium' or 'short', dictates the level of
%                details for output sample description
%
% Outputs:
%   desc - a string describing the given data set.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2016, Australian Ocean Data Network (AODN) and Integrated 
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
%     * Neither the name of the AODN/IMOS nor the names of its contributors 
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
narginchk(1,2);

if ~isstruct(sam), error('sam must be a struct'); end

if nargin == 1
    detailLevel = 'full';
end

timeFmt = readProperty('toolbox.timeFormat');

timeRange = ['from ' datestr(sam.time_coverage_start, timeFmt) ' to ' ...
             datestr(sam.time_coverage_end,   timeFmt)];

[~, fName, fSuffix] = fileparts(sam.toolbox_input_file);

fName = [fName fSuffix];

switch detailLevel
    case 'short'
        desc = [   sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' @'   num2str(sam.meta.depth) 'm'];
        
    case 'medium'
        desc = [   sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' ('   fName ')'];
        
    otherwise
        % full details
        desc = [   sam.meta.site_id ...
            ' - '  sam.meta.instrument_make ...
            ' '    sam.meta.instrument_model ...
            ' SN=' sam.meta.instrument_serial_no ...
            ' @'   num2str(sam.meta.depth) 'm' ...
            ' '    timeRange ...
            ' ('   fName ')'];
end