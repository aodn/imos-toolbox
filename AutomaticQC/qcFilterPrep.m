function sam = qcFilterPrep( sam, filtername )
%QCFILTERPREP is only relevant for Real Time data that needs
% to go through Prep QC filters. For regular delayed mode data this should
% be transparent and leads straight to the regular main QC filters.
%
% Inputs:
%   sam         - Cell array of sample data structs, containing the data
%                 over which the qc routines are to be executed.
%   filterName  - String name of the QC test to be applied.
%
% Outputs:
%   sam         - Same as input, after QC routines have been run over it.
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

fun = [filtername 'Prep'];
if exist(fun, 'file') % MATLAB function
    fun = str2func(fun);
    type{1} = 'dimensions';
    type{2} = 'variables';
    qcPrep=struct;
    for m = 1:length(type)
        for k = 1:length(sam.(type{m}))
            % check for previously computed stddev
            if isfield(sam.meta, 'qcPrep')
                if isfield(sam.meta.qcPrep, filtername)
                    if isfield(sam.meta.qcPrep.(filtername), type{m})
                        qcPrep.(type{m}){k} = sam.meta.qcPrep.(filtername).(type{m}){k};
                        continue;
                    end
                end
            end

            data  = sam.(type{m}){k}.data;
            qcPrep.(type{m}){k} =  fun(sam, data, k, type{m});
        end
    end
    sam.meta.qcPrep.(filtername) = qcPrep;
else
    sam.meta.qcPrep.(filtername) = 'none';
end

end