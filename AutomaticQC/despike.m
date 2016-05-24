function isFlagged = despike(time, data, maxAllowedGrad, maxAllowedSpikeTime)
%DESPIKEPOS identifies increasing anomalies / spikes based on the data 
% temporal gradient.
%
% An increasing spike / anomaly in the signal will translate into a 
% positive spike followed by a negative one in the temporal gradient. If
% both temporal gradient spikes are greater than maxAllowedGrad and are
% within maxAllowedSpikeTime then the spike / anomaly identifed is valid and will be
% flagged. Start of increasing anomaly / spike is identified by the temporal
% gradient evolving from < gradThreshold/2 to > gradThreshold/2, within
% maxAllowedSpikeTime distance from the data spike. End of increasing anomaly / spike is 
% identified by the temporal gradient evolving from > -gradThreshold/2 to 
% < -gradThreshold/2, within maxAllowedSpikeTime distance from the data spike.
%
%
% Inputs:
%   time                - the vector of time for data to check.
%
%   data                - the vector of data to check.
%
%   maxAllowedGrad      - value in data unit per second of data
%                       temporal gradient above which the corresponding data 
%                       could be considered as an anomaly / spike.
%
%   maxAllowedSpikeTime - maximum time allowed between the start and end of a
%                       potential anomaly / spike.
%
% Outputs:
%   isFlagged           - logical vector the same length as data, with true for 
%                       identified anomaly / spike regions.
%
% Author:       Sebastien Mancini <sebastien.mancini@utas.edu.au>
%               Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
narginchk(4, 4);

isFlagged = false(size(data));

% temporal gradient
gradient = [NaN; diff(data)./(diff(time)*60*60*24)];

% look for positive / negative gradients that are greater / smaller than
% gradThreshold
iGradSpikePos    = gradient >  maxAllowedGrad;
iGradSpikeNeg    = gradient < -maxAllowedGrad;
timeGradSpikePos = time(iGradSpikePos);
timeGradSpikeNeg = time(iGradSpikeNeg);

% look for potential starts and ends of any spike / anomaly in the signal
midGradThreshold = maxAllowedGrad/2; % good compromise for a reasonable number
iGoesUp      = (gradient(1:end-1) <  midGradThreshold) & (gradient(2:end) >  midGradThreshold);
iGoesDown    = (gradient(1:end-1) < -midGradThreshold) & (gradient(2:end) > -midGradThreshold);
timeGoesUp   = time([iGoesUp;   false]);
timeGoesDown = time([iGoesDown; false]);

nSpikeUp   = length(timeGradSpikePos);
nSpikeDown = length(timeGradSpikeNeg);
nGoesUp    = length(timeGoesUp);
nGoesDown  = length(timeGoesDown);

maxAllowedSpikeTime = maxAllowedSpikeTime/(60*60*24); % convert from seconds to days

for i=1:nSpikeUp
    for j=1:nSpikeDown
        % we identify a spike / anomaly in the signal as something that 
        % would have a consecutive positive then negative gradient spike 
        % (or vice-versa) that would be close enough to each other
        durationSpike = timeGradSpikeNeg(j) - timeGradSpikePos(i);
        signSpike = sign(durationSpike);
        if (abs(signSpike) > 0) && (abs(durationSpike) < maxAllowedSpikeTime)
                
            % let's allocate some rough boundaries in time to this spike / anomaly
            if signSpike > 0 
                timeGradSpikeStart = timeGradSpikePos(i);
                timeGradSpikeEnd = timeGradSpikeNeg(j);
            else
                timeGradSpikeStart = timeGradSpikeNeg(j);
                timeGradSpikeEnd = timeGradSpikePos(i);
            end
            flagBoundMin = timeGradSpikeStart - maxAllowedSpikeTime;
            flagBoundMax = timeGradSpikeEnd + maxAllowedSpikeTime;
            
            % now we can try to refine these boundaries
            if signSpike > 0 
                nStart = nGoesUp;
                nEnd = nGoesDown;
                timeStart = timeGoesUp;
                timeEnd = timeGoesDown;
            else
                nStart = nGoesDown;
                nEnd = nGoesUp;
                timeStart = timeGoesDown;
                timeEnd = timeGoesUp;
            end
            for k=nStart:-1:1 % incrementing decreasingly gets us to the closer starting boundary first
                if (timeGradSpikeStart - timeStart(k) < maxAllowedSpikeTime) && ...
                        (timeGradSpikeStart - timeStart(k) >= 0)
                    flagBoundMin = timeStart(k);
                    break; % no need to continue iterrating, let's move on
                end
            end
            for l=1:nEnd % incrementing increasingly gets us to the closer ending boundary first
                if (timeEnd(l) - timeGradSpikeEnd < maxAllowedSpikeTime) && ...
                        (timeEnd(l) - timeGradSpikeEnd >= 0)
                    flagBoundMax = timeEnd(l);
                    break; % no need to continue iterrating, let's move on
                end
            end
            
            % we can finally flag the portion of spike / anomaly based on 
            % its boundaries
            iSpike = time > flagBoundMin & time < flagBoundMax;
            if any(iSpike)
                isFlagged(iSpike) = true;
            end
    
            break; % no need to continue iterrating, let's move on
        end
    end
end

end