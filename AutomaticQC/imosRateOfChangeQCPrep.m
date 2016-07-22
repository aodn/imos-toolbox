function [ qcPrep ] = imosRateOfChangeQCPrep( sample_data, data, k, type )
%IMOSRATEOFCHANGEQCPREP computes the standard deviation of the first
% relevant month of data.
%
% Inputs:
%   sample_data - struct containing the data set.
%
%   data        - the vector/matrix of data to check.
%
%   k           - Index into the sample_data variable vector.
%
%   type        - dimensions/variables type to check in sample_data.
%
%
% Outputs:
%   qcPrep      - struct including results of Prep QC procedure.
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
qcPrep= struct;

if ~strcmp(type, 'variables'), return; end

qcSet    = str2double(readProperty('toolbox.qc_set'));
rawFlag  = imosQCFlag('raw',  qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');
pGoodFlag= imosQCFlag('probablyGood', qcSet, 'flag');

% matrix case, we process line by line for timeserie study
% purpose
len2 = size(data, 2);
stdDev = nan(1, len2);
for i=1:len2
    lineData = data(:, i);
    
    % let's consider time in seconds
    tTime = 'dimensions';
    iTime = getVar(sample_data.(tTime), 'TIME');
    if iTime == 0, return; end
    time = sample_data.(tTime){iTime}.data * 24 * 3600;
    if size(time, 1) == 1
        % time is a row, let's have a column instead
        time = time';
    end
    
    % We compute the standard deviation on relevant data for the first month of
    % the time serie
    iGoodData = (sample_data.(type){k}.flags(:,i) == goodFlag | ...
        sample_data.(type){k}.flags(:,i) == pGoodFlag | ...
        sample_data.(type){k}.flags(:,i) == rawFlag);
    if any(iGoodData)
        dataRelevant = lineData(iGoodData);
        clear lineData;
        timeRelevant = time(iGoodData);
        iFirstNotBad = find(iGoodData, 1, 'first');
        clear iGoodData
        iRelevantTimePeriod = (timeRelevant >= time(iFirstNotBad) & timeRelevant <= time(iFirstNotBad)+30*24*2600);
        clear timeRelevant
        if any(iRelevantTimePeriod)
            % std only applies to single or double (both are floats of different precision)
            if ~isa(dataRelevant, 'float')
                dataRelevant = single(dataRelevant);
            end
            stdDev(i) = std(dataRelevant(iRelevantTimePeriod));
        else
            stdDev(i) = NaN;
        end
    else
        stdDev(i) = NaN;
    end
end

qcPrep.stdDev = stdDev;

end