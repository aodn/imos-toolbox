function [cmap] = conversion_mappings(sensors, name_extension, xmit_voltage_scale, frame_of_reference)
%function [cmap] = conversion_mappings(sensors, name_extension,xmit_voltage_scale, frame_of_reference)
%
% Load the Conversion mappings for workhorse ADCP
%
% Inputs:
%
% sensors [struct] - A structure with sensors switches.
% name_extension [char] - The variable name extension for velocity and Heading.
% xmit_voltage_scale [double] - The transmit voltage scales. See adcp_info structure.
% frame_of_reference [char] - The frame of reference ['earth' | 'beam']
%
% Outputs:
% cmap[struct] - the conversion mapping structure.
%                fieldnames - destination variable names
%                fieldvalues[cell[char]] - function handles for the conversion.
%
% Example:
%
% %acoustic beam data.
% sensors = struct('Temperature',true,'Depth',true,'Conductivity',false,'SpeedOfSound',true,'Pitch',true,'Roll',true,'Heading',true);
% name_extension = '';
% xmit_scale = 999;
%
% cmap = Workhorse.conversion_mappings(sensors,name_extension,xmit_scale,'beam');
% assert(all(structfun(@isfunctionhandle,cmap)))
% assert(cmap.('VEL1')(1000)==1) % mm/s -> m/s
% assert(cmap.('TEMP')(2700)==27) % 0.01deg -> deg
% assert(cmap.('PRES_REL')(1000)==1) % decpa -> pa
% assert(cmap.('HEADING')(1200)==12) % 0.01deg -> deg
% assert(int64(cmap.('TX_VOLT')(1e6))==int64(999)) % xmit_volt*xmit_scale -> volt
%
% % enu data with magnetic north.
% name_extension = '_MAG';
% cmap = Workhorse.conversion_mappings(sensors,name_extension,xmit_scale,'earth');
% assert(all(structfun(@isfunctionhandle,cmap)))
% assert(cmap.('VCUR_MAG')(1000)==1) % mm/s -> m/s
% assert(cmap.('TEMP')(2700)==27) % 0.01deg -> deg
% assert(cmap.('PRES_REL')(1000)==1) % decpa -> pa
% assert(cmap.('HEADING_MAG')(1200)==12) % 0.01deg -> deg
% assert(int64(cmap.('TX_VOLT')(1e6))==int64(999)) % xmit_volt*xmit_scale -> volt
%
% % enu data true north.
% name_extension = '';
% cmap = Workhorse.conversion_mappings(sensors,name_extension,xmit_scale,'earth');
% assert(all(structfun(@isfunctionhandle,cmap)))
% assert(cmap.('VCUR')(1000)==1) % mm/s -> m/s
%
narginchk(4, 4);
cmap = struct();

mms_to_ms = @(x)(0.001 * x); % mm/s -> m/s
cdeg_to_deg = @(x)(0.01 * x); % 0.01 deg -> deg
decapascal_to_decibar = @(x)(0.001 * x); %decapascal -> decibar
xmitcounts_to_volt = @(x)(1e-6 * xmit_voltage_scale * x);

switch frame_of_reference
    case 'earth'
        cmap.(['VCUR' name_extension]) = mms_to_ms;
        cmap.(['UCUR' name_extension]) = mms_to_ms;
        cmap.('WCUR') = mms_to_ms;
        cmap.('ECUR') = mms_to_ms;
    case 'beam'
        cmap.('VEL1') = mms_to_ms;
        cmap.('VEL2') = mms_to_ms;
        cmap.('VEL3') = mms_to_ms;
        cmap.('VEL4') = mms_to_ms;
end

if sensors.Temperature
    cmap.('TEMP') = cdeg_to_deg;
end

if sensors.Depth
    cmap.('PRES_REL') = decapascal_to_decibar;
end

if sensors.Pitch
    cmap.('PITCH') = cdeg_to_deg;
end

if sensors.Roll
    cmap.('ROLL') = cdeg_to_deg;
end

if sensors.Heading
    cmap.(['HEADING' name_extension]) = cdeg_to_deg;
end

cmap.('TX_VOLT') = xmitcounts_to_volt;

end
