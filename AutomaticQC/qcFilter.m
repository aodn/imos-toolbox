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
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
    sam = qcFilterPrep (sam, filterName);
    
    sam = qcFilterMain (sam, filterName, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, cancel);
end