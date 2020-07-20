function [veast,vnrth,wvel,evel]=rdiBeam2Earth(b1,b2,b3,b4,head,pitch,roll,ba,cvxccv,updown, distance)
% Function to convert ADCP beam velocities to Earth coordinate velocity.
% b1,b2,b3,b4 are four beam velocities
% head is the heading reading, in degrees.
% pitch is the pitch reading, in degrees.
% roll is the roll reading, in degrees.
% ba is the beam angle, in degrees.
% cvxccv is 1 for a convex xdcr, other than 1 for a concave xdcr.  Usually 1.
% updwon is 0 for a down-looking instrument, other than 0 for an up-looker.
%
% Calls matlab routines beam2inst.m and inst2earth.m.
%
head = head*0.01;
pitch = pitch *0.01;
roll = roll * 0.01;
% make pitch, roll, heading the same size as b1, b2, b3, b4
elev=[-70 -70 -70 -70]; % default elev for 20o
azi=[270 90 0 180];
if updown == 1 %uplooking
    txtup = 'up';
else
    txtup = 'down';
end
[veast,vnrth,wvel,evel] = deal(NaN*b1);
% have to bin map it first. Even if the EX bit is set for bin
% mapping, if the data is collected in beam coordinates, bin mapping
% does not occur on board.
[b1,b2,b3,b4] = binmap(b1,b2,b3,b4,head,pitch,roll,ba,distance);
for a = 1:length(pitch)
    beamdat = [b1(a,:); b2(a,:); b3(a,:); b4(a,:)];
    thePitch=atand(tand(pitch(a))*cosd(roll(a))); % CBluteau as per RDI coordinate transformation manual Eq 19 when EZxxx1xxx is set
    i2e=inst2earth(head(a),thePitch,roll(a),updown);
    b2i=beam2inst(ba,cvxccv);
    V = (i2e*b2i*beamdat)'; %V = [u v w V_err];
    veast(a,:) = V(:,1)';
    vnrth(a,:) = V(:,2)';
    wvel(a,:) = V(:,3)';
    evel(a,:) = V(:,4)';
end
return
end

function y=inst2earth(head,pitch,roll,updown)
% Creates transformation matrix for converting from instrument coordinates to
% earth coordinates based on heading, pitch and roll information.  Assumes
% arguments are given in degrees.  Updown should be 0 for a down-looking system,
% and some number other than 0 for an up-looking system.
%
% Note that the matrix created is 4x4, with the additional row and column added
% so that the error velocity calculated in beam2inst.m will carry through.
%
% Convert input degrees to radians
hrad=head*pi/180;
prad=pitch*pi/180;
if updown == 0
    rrad=roll*pi/180;
else
    rrad=(roll+180)*pi/180;
end
zero= 0;
one = 1;
%
% Create the heading rotation matrix:
%
h=[cos(hrad)  sin(hrad)  zero zero
    -sin(hrad) cos(hrad) zero zero
    zero zero one zero
    zero zero zero one];
%
% Create the pitch rotation matrix:
%
p=[one zero zero zero
    zero  cos(prad) -sin(prad) zero
    zero  sin(prad) cos(prad) zero
    zero zero zero one];
%
% Create the roll rotation matrix:
%
r=[cos(rrad) zero sin(rrad) zero
    zero  one  zero zero
    -sin(rrad) zero cos(rrad) zero
    zero zero zero one];
%
% create the final matrix
%
y=h*p*r;
return
end

function y=beam2inst(ba,c)
% Creates transformation matrix for converting from beam coordinates to
% instrument coordinates based the beam angle.
%
% ba is the beam angle of the ADCP (typically either 20 or 30 degrees)
% c is whether the instrument is convex (c=1) or concave (c other than 1). Nearly
% all ADCPs are convex (some early vessel-mounted systems were concavbe).
%
% Create the apropriate scale factors:
%
barad=ba*pi/180;
a=1/(2*sin(barad));
b=1/(4*cos(barad));
d=a/sqrt(2);
%
% Create the matrix:
%
y=[c*a -c*a 0 0
    0 0 -c*a c*a
    b b b b
    d d -d -d];
return
end

function [b1m,b2m,b3m,b4m] = binmap(b1,b2,b3,b4,head,pitch,roll,ba,distance)
distAlongBeams = distance';
pitch = pitch*pi/180;
roll  = roll*pi/180;

beamAngle = ba*pi/180;
nBins = length(distAlongBeams);

% RDI 4 beams
nonMappedHeightAboveSensorBeam1 = (cos(beamAngle + roll)/cos(beamAngle)) * distAlongBeams;
nonMappedHeightAboveSensorBeam1 = repmat(cos(pitch), 1, nBins) .* nonMappedHeightAboveSensorBeam1;

nonMappedHeightAboveSensorBeam2 = (cos(beamAngle - roll)/cos(beamAngle)) * distAlongBeams;
nonMappedHeightAboveSensorBeam2 = repmat(cos(pitch), 1, nBins) .* nonMappedHeightAboveSensorBeam2;

nonMappedHeightAboveSensorBeam3 = (cos(beamAngle - pitch)/cos(beamAngle)) * distAlongBeams;
nonMappedHeightAboveSensorBeam3 = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam3;

nonMappedHeightAboveSensorBeam4 = (cos(beamAngle + pitch)/cos(beamAngle)) * distAlongBeams;
nonMappedHeightAboveSensorBeam4 = repmat(cos(roll), 1, nBins) .* nonMappedHeightAboveSensorBeam4;

nSamples = length(pitch);
mappedHeightAboveSensor = repmat(distAlongBeams, nSamples, 1);

% we can now interpolate mapped values per bin when needed for each
% impacted parameter

% only process variables that are in beam coordinates
for beamnumber = 1:4
    switch beamnumber
        case 1
            nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam1;
            nonMappedData = b1;
        case 2
            nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam2;
            nonMappedData = b2;
        case 3
            nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam3;
            nonMappedData = b3;
        case 4
            nonMappedHeightAboveSensor = nonMappedHeightAboveSensorBeam4;
            nonMappedData = b4;
    end
    
    % let's now interpolate data values at nominal bin height for
    % each profile
    
    mappedData = NaN(size(nonMappedData));
    for i=1:nSamples
        %                 mappedData(i,:) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,:));
        %the LeanInterp code is nearly twice as quick as interp1
        mappedData(i,:) = LeanInterp(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,:));
        % there is a risk of ending up with a NaN for the first bin
        % while the difference between its nominal and tilted
        % position is negligeable so we can arbitrarily set it to
        % its value when tilted (RDI practice).
        mappedData(i,1) = nonMappedData(i,1);
        % there is also a risk of ending with a NaN for the last
        % good bin (one beam has this bin slightly below its
        % bin-mapped nominal position and that's a shame we miss
        % it). For this bin, using extrapolation methods like
        % spline could still be ok.
        %                 iLastGoodBin = find(isnan(mappedData(i,:)), 1, 'first');
        %                 mappedData(i,iLastGoodBin) = interp1(nonMappedHeightAboveSensor(i,:), nonMappedData(i,:), mappedHeightAboveSensor(i,iLastGoodBin), 'spline');
    end
    
    %assign back:
    switch beamnumber
        case 1
            b1m = nonMappedData;
        case 2
            b2m = nonMappedData;
        case 3
            b3m = nonMappedData;
        case 4
            b4m = nonMappedData;
    end
    
end
return
end
