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