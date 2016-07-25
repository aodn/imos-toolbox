function sam = qcFilter(sam, filterName, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, cancel)
%QCFILTER Runs the given data set through the given automatic Prep QC filters
% and Main QC filters. This is only relevant for Real Time data that needs
% to go through Prep QC filters. For regular delayed mode data this should
% be transparent as the result of the Prep QC is not re-used next.
%
% Inputs:
%   sam         - Cell array of sample data structs, containing the data
%                 over which the qc routines are to be executed.
%   filterName  - String name of the QC test to be applied.
%   auto        - Optional boolean argument. If true, the automatic QC
%                 process is executed automatically (interesting, that),
%                 i.e. with no user interaction.
%   rawFlag     - flag for non QC'd status.
%   goodFlag    - flag for good QC test status.
%   probGoodFlag- flag for probably good QC test status.
%   probBadFlag - flag for probably bad QC test status.
%   badFlag     - flag for bad QC test status.
%   cancel      - cancel QC app process integer code.
%
% Outputs:
%   sam         - Same as input, after QC routines have been run over it.
%                 Will be empty if the user cancelled/interrupted the QC
%                 process.
%
% Author:       Greg Coleman <g.coleman@aims.gov.au>
% Contributor:	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
    sam = qcFilterPrep (sam, filterName);
    
    sam = qcFilterMain (sam, filterName, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, cancel);
end