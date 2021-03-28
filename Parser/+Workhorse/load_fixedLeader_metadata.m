function [meta] = load_fixedLeader_metadata(fixed)
%function [meta] = load_fixedLeader_metadata(fixed)
%
% Load the meta(data) structure based on the ensemble
% fixed Leader structure.
%
% The metadata struct is compatible with the
% previous versions of the toolbox with all new
% components within the adcp_info field.
%
% Inputs:
%
% fixed [struct] - the fixedLeader fieldname struct
%         from readWorkhorseEnsembles.
%
% Outputs:
%
% meta [struct] - The toolbox metadata structure.
%
%
% Examples:
%
% author: hugo.oliveira@utas.edu.au
%

%TODO: don't use mode, but check for uniqueness instead.
%      A fixedLeader should never change anyway, and if there is
%      a change, everything downstream from the change should be ignored.
sysconfig = mode(fixed.systemConfiguration, 1);
adcp_info = Workhorse.translate_system_configuration(sysconfig);

stconfig = mode(fixed.sensorSource, 1);
adcp_info.sensors_settings = Workhorse.translate_internal_sensor_configuration(stconfig);

saconfig = mode(fixed.sensorsAvailable, 1); %use Source instead of Available to import speed of Sound if computed.
adcp_info.sensors_available = Workhorse.translate_internal_sensor_configuration(saconfig);

ctconfig = mode(fixed.coordinateTransform, 1);
adcp_info.coords = Workhorse.translate_coordinate_transformation_configuration(ctconfig);

adcp_info.number_of_beams = mode(fixed.numBeams);

meta.adcp_info = adcp_info; %new structure information.

%standard names and fields at root level.
meta.featureType = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
meta.beam_angle = adcp_info.beam_angle;

meta.instrument_make = 'Teledyne RDI';
meta.instrument_model = [adcp_info.model_name ' Workhorse ADCP'];
meta.instrument_serial_no = num2str(mode(fixed.instSerialNumber));

cpuFirmwareVersion = unique(fixed.cpuFirmwareVersion);
cpuFirmwareRevision = unique(fixed.cpuFirmwareRevision);

if numel(cpuFirmwareVersion) > 1 || numel(cpuFirmwareRevision) > 1
    warnmsg('Non unique cpu Firmware Information. This indicate a problem with the ADCP ensemble reading code or binary file')
end

meta.instrument_firmware = [num2str(cpuFirmwareVersion) '.' num2str(cpuFirmwareRevision)];

meta.binSize = 0.01 * mode(fixed.depthCellLength); %cm to m
meta.compass_correction_applied = 0.01 * mode(fixed.headingBias); % 0.01 deg -> deg; Range = -179.99 to 180.00degrees

end
