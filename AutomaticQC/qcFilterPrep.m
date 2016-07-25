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