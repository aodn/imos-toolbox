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
%
% imap = Workhorse.import_mappings(sensors,4,'','beam');
% fields = fieldnames(imap);
% assert(inCell(fields,'VEL1'))
% assert(~inCell(fields,'VCUR'))
% assert(inCell(fields,'HEADING'))
% assert(inCell(fields,'ABSIC4'))
%
% imap = Workhorse.import_mappings(sensors,4,'','earth');
% fields = fieldnames(imap);
% assert(inCell(fields,'VCUR'))
% assert(~inCell(fields,'VEL1'))
% assert(inCell(fields,'HEADING'))
% assert(inCell(fields,'ABSIC4'))
%
% %MAG declination renaming.
%
% imap = Workhorse.import_mappings(sensors,4,'_MAG','earth');
% fields = fieldnames(imap);
%
% assert(~inCell(fields,'VEL1_MAG'))
% assert(inCell(fields,'VCUR_MAG'))
% assert(isequal(imap.('VCUR_MAG'),{'velocity','velocity1'}))
% assert(inCell(fields,'UCUR_MAG'))
% assert(isequal(imap.('UCUR_MAG'),{'velocity','velocity2'}))
%
% assert(inCell(fields,'ECUR'))
% assert(inCell(fields,'WCUR'))
%
% assert(inCell(fields,'CMAG1'))
% assert(isequal(imap.('CMAG1'),{'corrMag','field1'}))
%
% assert(inCell(fields,'PERG4'))
% assert(isequal(imap.('PERG4'),{'percentGood','field4'}))
%
% assert(inCell(fields,'ABSIC4'))
% assert(isequal(imap.('ABSIC4'),{'echoIntensity','field4'}))
%
% assert(inCell(fields,'HEADING_MAG'))
% assert(isequal(imap.('HEADING_MAG'),{'variableLeader','heading'}))
% assert(inCell(fields,'TX_VOLT'))
% assert(isequal(imap.('TX_VOLT'),{'variableLeader','adcChannel1'}))
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(4, 4);
switch frame_of_reference
    case 'earth'
        vel_vars = {['VCUR' name_extension], ['UCUR' name_extension], 'WCUR'};
        if num_beams>3
            vel_vars{end+1} = 'ECUR';
        end
    case 'beam'
        vel_vars = {'VEL1','VEL2','VEL3'};
        if num_beams>3
            vel_vars{end+1} = 'VEL4';
        end
end

beam_vars = {'ABSIC1', 'ABSIC2', 'ABSIC3', 'ABSIC4', 'CMAG1', 'CMAG2', 'CMAG3', 'CMAG4', 'PERG1', 'PERG2', 'PERG3', 'PERG4'};
ts_vars = {};

imap = struct();

for k = 1:num_beams
    imap.(vel_vars{k}) = {'velocity', ['velocity' num2str(k)]};
    imap.(['ABSIC' num2str(k)]) = {'echoIntensity', ['field' num2str(k)]}; %backscatter
    imap.(['CMAG' num2str(k)]) = {'corrMag', ['field' num2str(k)]}; %correlation
    imap.(['PERG' num2str(k)]) = {'percentGood', ['field' num2str(k)]}; %percentGood
end

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
