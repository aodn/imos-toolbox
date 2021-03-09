function [adcp_system] = translate_system_configuration(sysconfig)
% function [adcp_system] = translate_system_configuration(sysconfig)
%
% Return the adcp information table,
% based on the instrument manufacturer system configuration
% bytes no. 5 & 6.
%
% For more information, see readWorkhorseParse.m or
% page 178 in Rio Grande  ADCP Operation Manual, Teledyne RD Instruments, P/N 957-6241-00 (September 2013)
%
% Inputs:
%
% sysconfig[logical] - The system configuration logical array representing the 8 LSB
%                      bits and the 8 MSB bits.
%                      Note: Bit-padding is assumed (length(sysconfig)==16)
%
% Outputs:
%
%  adcp_system - A struct with all derived system config.
%             LSB derived fields:
%
%  adcp_system.beam_face_config[char] - Static beam facing config [ 'up' | 'down' ]
%  adcp_system.xdcr_hd_attached[logical] - HD Transducer attached [true,false]
%  adcp_system.sensor_config[str] - The 5th,4th sensor config bits.
%  adcp_system.beam_pattern[str] - beam pattern of ADCP ['concave','convex']
%  adcp_system.system_freq[double] - the ADCP system frequency.
%  adcp_system.model_name[str] - the ADCP model.
%  adcp_system.xmit_voltage_scale[double] - Transmission voltage scale factors.
%
%             MSB derived fields:
%
%  adcp_system.beam_config[str] - the beam configuration string.
%  adcp_system.beam_angle[double] - the physical beam angle of transducers.
%
% Example:
%
% %A quarter master, upfacing, with hd xdcr, convex, 150khz adcp
% lsb = ['11001001'];
% %4beam no demod, 20deg beam angle
% msb = ['01000001'];
% [s] = Workhorse.translate_system_configuration(bin2logical([lsb msb]));
% assert(strcmpi(s.beam_face_config,'up'))
% assert(s.xdrc_hd_attached)
% assert(strcmpi(s.sensor_config,'00'))
% assert(strcmpi(s.beam_pattern,'convex'))
% assert(s.system_freq==150.00)
% assert(strcmpi(s.model_name,'Quartermaster'))
% assert(s.xmit_voltage_scale==592157)
% assert(strcmpi(s.beam_config,'4-BEAM JANUS CONFIG'))
% assert(s.beam_angle==20.00)
%
%
% author: hugo.oliveira@utas.edu.au
%

narginchk(1, 1)

if ~islogical(sysconfig)
    errormsg('Input should be a logical representing bit configuration')
elseif numel(sysconfig) ~= 16
    errormsg('system config should be composed of 16 logical array representing two bytes')
end

%map the manual table bits to left to right indexing.
bitmap = containers.Map({0, 1, 2, 3, 4, 5, 6, 7}, {8, 7, 6, 5, 4, 3, 2, 1});

lsb = sysconfig(1:8);
adcp_system = struct;

if lsb(bitmap(7))
    adcp_system.beam_face_config = 'up';
else
    adcp_system.beam_face_config = 'down';
end

adcp_system.xdrc_hd_attached = lsb(bitmap(6));
adcp_system.sensor_config = logical2bin(lsb([bitmap(5), bitmap(4)]));

if lsb(bitmap(3))
    adcp_system.beam_pattern = 'convex';
else
    adcp_system.beam_pattern = 'concave';
end

model_bits = [bitmap(2), bitmap(1), bitmap(0)];
model_id = logical2bin(lsb(model_bits));

switch model_id% see readWorkhorseEnsembles.m table.
    case '000'
        adcp_system.system_freq = 75;
        adcp_system.model_name = 'Long Ranger';
        adcp_system.xmit_voltage_scale = 2092719;
    case '001'
        adcp_system.system_freq = 150;
        adcp_system.model_name = 'Quartermaster';
        adcp_system.xmit_voltage_scale = 592157;
    case '010'
        adcp_system.system_freq = 300;
        adcp_system.model_name = 'Sentinel or Monitor';
        adcp_system.xmit_voltage_scale = 592157;
    case '011'
        adcp_system.system_freq = 600;
        adcp_system.model_name = 'Sentinel or Monitor';
        adcp_system.xmit_voltage_scale = 380667;
    case '100'
        adcp_system.system_freq = 1200;
        adcp_system.model_name = 'Sentinel or Monitor';
        adcp_system.xmit_voltage_scale = 253765;
    case '101'
        adcp_system.system_freq = 2400;
        adcp_system.model_name = 'DVS';
        adcp_system.xmit_voltage_scale = 253765;
    otherwise
        errormsg('ADCP system frequency bit is invalid.')
end

msb = sysconfig(9:end);
beam_config_bits = [bitmap(7), bitmap(6), bitmap(5), bitmap(4)];
beam_config = logical2bin(msb(beam_config_bits));

switch beam_config
    case '0100'
        adcp_system.beam_config = '4-BEAM JANUS CONFIG';
    case '0101'
        adcp_system.beam_config = '5-BEAM JANUS CONFIG DEMOD';
    case '1111'
        adcp_system.beam_config = '5-BEAM JANUS CONFIG 2 DEMOD';
end

beam_angle_bits = [bitmap(1), bitmap(0)];
beam_angle = logical2bin(msb(beam_angle_bits));

switch beam_angle
    case '00'
        adcp_system.beam_angle = 15;
    case '01'
        adcp_system.beam_angle = 20;
    case '10'
        adcp_system.beam_angle = 30;
    case '11'
        warning('Non-standard Beam angle detected');
        adcp_system.beam_angle = [];
end

end
