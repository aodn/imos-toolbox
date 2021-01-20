function [sensors] = translate_internal_sensor_configuration(sconfig)
% function [sensors] = translate_internal_sensor_configuration(sconfig)
%
% Return the adcp sensors table,
% based on the instrument manufacturer sensor byte no 32.
%
%
% For more information, see readWorkhorseParse.m or
% page 180 in Rio Grande ADCP Operation Manual, Teledyne RD Instruments, P/N 957-6241-00 (September 2013).
%
% Note that V-ADCP Operation manual, page 88, Teledyne RD Instrument, P/N 95B-6031-00 (March 204),
% contains the same information but with a missing, empty, left-bit in table description.
%
% Inputs:
%
% sconfig[logical] - The sensor Avail logical array representing the 32 byte position.
%
% Outputs:
%
%  sensors [struct] - A struct with all sensors computation switches.
%  sensors.SpeedOfSound
%  sensors.Depth
%  sensors.Heading
%  sensors.Pitch
%  sensors.Roll
%  sensors.Conductivity
%  sensors.Temperature
%
% Example:
%
% % a standard ADCP config.
% sensors = Workhorse.translate_internal_sensor_configuration(bin2logical('00111101'));
% assert(~sensors.SpeedOfSound)
% assert(sensors.Depth)
% assert(sensors.Heading)
% assert(sensors.Pitch)
% assert(sensors.Roll)
% assert(~sensors.Conductivity)
% assert(sensors.Temperature)
%
narginchk(1, 1)

if ~islogical(sconfig)
    error('First argument must be a logical array')
elseif numel(sconfig) ~= 8
    error('First argument must be a logical array representing 8 bits')
end

sensors.SpeedOfSound = sconfig(2);
sensors.Depth = sconfig(3);
sensors.Heading = sconfig(4);
sensors.Pitch = sconfig(5);
sensors.Roll = sconfig(6);
sensors.Conductivity = sconfig(7);
sensors.Temperature = sconfig(8);
end
