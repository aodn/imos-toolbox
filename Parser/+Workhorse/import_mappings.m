function [imap, vel_vars, beam_vars, ts_vars] = import_mappings(sensors, num_beams, name_extension, frame_of_reference)
%function [imap, vel_vars, beam_vars, ts_vars] = import_mappings(sensors, num_beams, name_extension, frame_of_reference)
%
% Load the import mappings for workhorse ADCP
%
% Inputs:
%
% sensors [struct] - A structure with sensors switches.
% num_beams [int] - The number of beams of the ADCP
% name_extension [char] - The variable name extension for velocity and Heading.
% frame_of_reference [char] - the frame of reference ['earth' | 'beam']
%
%
% Outputs:
% imap[struct] - the import mapping structure.
%                fieldnames - destination variable names
%                fieldvalues[cell[char]] - location in the ensembles struct.
% vel_vars[cell] - cell containing velocity variable names (2d-arrays).
% beam_vars[cell] - cell containing beam variable names (2d-arrays).
% ts_vars[cell] - cell containing series variable names (1d-arrays).
%
% Examples:
%
% sensors = struct('Temperature',true,'Depth',true,'Conductivity',false,'SpeedOfSound',true,'Pitch',true,'Roll',true,'Heading',true);
% imap = Workhorse.import_mappings(sensors,4,'','beam');
% fields = fieldnames(imap);
% assert(inCell(fields,'VEL1'))
% assert(~inCell(fields,'VCUR'))
% assert(inCell(fields,'HEADING'))
% assert(inCell(fields,'ABSIC4'))
% assert(isequal(imap.('VEL1'),{'velocity','velocity1'}))
% assert(isequal(imap.('VEL2'),{'velocity','velocity2'}))
% assert(isequal(imap.('VEL3'),{'velocity','velocity3'}))
% assert(isequal(imap.('VEL4'),{'velocity','velocity4'}))
%
% imap = Workhorse.import_mappings(sensors,4,'','earth');
% fields = fieldnames(imap);
% assert(inCell(fields,'VCUR'))
% assert(~inCell(fields,'VEL1'))
% assert(inCell(fields,'HEADING'))
% assert(inCell(fields,'ABSIC4'))
% assert(isequal(imap.('UCUR'),{'velocity','velocity1'}))
% assert(isequal(imap.('VCUR'),{'velocity','velocity2'}))
% assert(isequal(imap.('WCUR'),{'velocity','velocity3'}))
% assert(isequal(imap.('ECUR'),{'velocity','velocity4'}))
%
% %MAG declination renaming.
%
% imap = Workhorse.import_mappings(sensors,4,'_MAG','earth');
% fields = fieldnames(imap);
%
% assert(~inCell(fields,'VEL1_MAG'))
% assert(inCell(fields,'UCUR_MAG'))
% assert(isequal(imap.('UCUR_MAG'),{'velocity','velocity1'}))
% assert(inCell(fields,'VCUR_MAG'))
% assert(isequal(imap.('VCUR_MAG'),{'velocity','velocity2'}))
% assert(inCell(fields,'WCUR'))
% assert(isequal(imap.('WCUR'),{'velocity','velocity3'}))
% assert(inCell(fields,'ECUR'))
% assert(isequal(imap.('ECUR'),{'velocity','velocity4'}))
%
% assert(inCell(fields,'ABSIC4'))
% assert(isequal(imap.('ABSIC4'),{'echoIntensity','field4'}))
% assert(inCell(fields,'CMAG3'))
% assert(isequal(imap.('CMAG3'),{'corrMag','field3'}))
% assert(inCell(fields,'PERG2'))
% assert(isequal(imap.('PERG2'),{'percentGood','field2'}))
%
% assert(inCell(fields,'HEADING_MAG'))
% assert(isequal(imap.('HEADING_MAG'),{'variableLeader','heading'}))
% assert(inCell(fields,'TX_VOLT'))
% assert(isequal(imap.('TX_VOLT'),{'variableLeader','adcChannel1'}))
%
% %test beam_vars
% [~,vel_vars,beam_vars,ts_vars] = Workhorse.import_mappings(sensors,3,'_MAG','earth');
% assert(inCell(vel_vars,'UCUR_MAG'))
% assert(inCell(vel_vars,'WCUR'))
% assert(inCell(beam_vars,'ABSIC1'))
% assert(inCell(beam_vars,'CMAG2'))
% assert(inCell(beam_vars,'PERG3'))
% assert(inCell(ts_vars,'HEADING_MAG'))
% assert(~inCell(ts_vars,'PSAL'))
%
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(4, 4);

imap = struct();

switch frame_of_reference
    case 'earth'
        imap.(['UCUR' name_extension]) = {'velocity', 'velocity1'};
        imap.(['VCUR' name_extension]) = {'velocity', 'velocity2'};
        imap.('WCUR') = {'velocity', 'velocity3'};
        vel_vars = {['UCUR' name_extension], ['VCUR' name_extension], 'WCUR'};
        if num_beams == 4 
            imap.('ECUR') = {'velocity', 'velocity4'};
            vel_vars{end+1} = 'ECUR';
        end
    case 'beam'
        imap.('VEL1') = {'velocity', 'velocity1'};
        imap.('VEL2') = {'velocity', 'velocity2'};
        imap.('VEL3') = {'velocity', 'velocity3'};
        vel_vars = {'VEL1','VEL2','VEL3'};
        if num_beams == 4 
            imap.('VEL4') = {'velocity', 'velocity4'};
            vel_vars{end+1} = 'VEL4';
        end
    otherwise
        errormsg('Frame of reference %s not implemented.',frame_of_reference)
end

%follow the order of previous definitions for compatibility
beam_vars = cell(1,num_beams*3); %ABSIC,CMAG,PERG
c=0;
for k=1:num_beams
    c=c+1;
    imap.(['ABSIC' num2str(k)]) = {'echoIntensity', ['field' num2str(k)]}; %backscatter
    beam_vars{c} = ['ABSIC' num2str(k)];
end
for k=1:num_beams
    c=c+1;
    imap.(['CMAG' num2str(k)]) = {'corrMag', ['field' num2str(k)]}; %correlation
    beam_vars{c} = ['CMAG' num2str(k)];
end
for k=1:num_beams
    c=c+1;
    imap.(['PERG' num2str(k)]) = {'percentGood', ['field' num2str(k)]}; %percentGood
    beam_vars{c} = ['PERG' num2str(k)];
end

ts_vars = {};
if sensors.Temperature
    ts_vars = [ts_vars, 'TEMP'];
    imap.('TEMP') = {'variableLeader', 'temperature'};
end

if sensors.Depth
    ts_vars = [ts_vars, 'PRES_REL'];
    imap.('PRES_REL') = {'variableLeader', 'pressure'};
end

if sensors.Conductivity
    ts_vars = [ts_vars, 'PSAL'];
    imap.('PSAL') = {'variableLeader', 'salinity'};
end

if sensors.SpeedOfSound
    ts_vars = [ts_vars, 'SSPD'];
    imap.('SSPD') = {'variableLeader', 'speedOfSound'};
end

if sensors.Pitch
    ts_vars = [ts_vars, 'PITCH'];
    imap.('PITCH') = {'variableLeader', 'pitch'};
end

if sensors.Roll
    ts_vars = [ts_vars, 'ROLL'];
    imap.('ROLL') = {'variableLeader', 'roll'};
end

if sensors.Heading
    ts_vars = [ts_vars, ['HEADING' name_extension]];
    imap.(['HEADING' name_extension]) = {'variableLeader', 'heading'};
end

ts_vars = [ts_vars, 'TX_VOLT'];
imap.('TX_VOLT') = {'variableLeader', 'adcChannel1'};
end
