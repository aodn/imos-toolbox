function [coords] = translate_coordinate_transformation_configuration(ctconfig)
%function [coords] = translate_coordinate_transformation_configuration(ctconfig)
%
% Return the adcp coordinate transformation table,
% based on the instrument manufacturer byte no 26.
%
% For more information, see readWorkhorseParse.m or
% page 180 in Rio Grande  ADCP Operation Manual, Teledyne RD Instruments, P/N 957-6241-00 (September 2013)
%
% Inputs:
%
% ctconfig[logical] - The system configuration logical array representing the 26 byte position.
%
% Outputs:
%
% coords[struct] - The coordinate structure.
%   frame_of_reference [str] = ['beam' | 'earth' | 'ship'] ;
%   used_tilt_in_transform [logical]
%   used_three_beam_solution [logical]
%   used_binmapping [logical]
%
% Example:
%
% %an adcp in ENU coordinates,  using tilts, 3-beam solution and binmapping.
% x = bin2logical('00011111');
% coords = Workhorse.translate_coordinate_transformation_configuration(x);
% assert(strcmpi(coords.frame_of_reference,'earth'))
% assert(coords.used_tilt_in_transform)
% assert(coords.used_tilt_in_transform)
% assert(coords.used_binmapping)
%
% %an adcp in Beam coordinates
% x = bin2logical('00000111');
% coords = Workhorse.translate_coordinate_transformation_configuration(x);
% assert(strcmpi(coords.frame_of_reference,'beam'))
%

transform_bit = logical2bin([ctconfig(4), ctconfig(5)]);

switch transform_bit
    case '00'
        coords.frame_of_reference = 'beam';
    case '01'
        coords.frame_of_reference = 'instrument';
    case '10'
        coords.frame_of_reference = 'ship';
    case '11'
        coords.frame_of_reference = 'earth';
end

coords.used_tilt_in_transform = ctconfig(6);
coords.used_three_beam_solution = ctconfig(7);
coords.used_binmapping = ctconfig(8);
end
