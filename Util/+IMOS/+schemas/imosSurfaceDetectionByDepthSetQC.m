function [bool, reason] = imosSurfaceDetectionByDepthSetQC(sample_data)
% function [bool,reason] = imosSurfaceDetectionByDepthSetQC(sample_data)
%
% Check if sample_data is a valid input for SurfaceDetectionByDepthSetQC.
%
% Inputs:
%
% sample_data [struct] - A toolbox dataset.
%
% Outputs:
%
% bool - True if dataset is valid. False otherwise.
% reason - The reasons why the dataset is invalid.
%
% Example:
%
% %see test_imosSurfaceDetectionByDepthSetQC.m
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)
reason = {};

if ~IMOS.adcp.contains_adcp_dimensions(sample_data)
    reason{1} = 'Not an adcp file.';
end

try
    avail_dimensions = IMOS.get(sample_data.dimensions, 'name');
    along_height = inCell(avail_dimensions, 'HEIGHT_ABOVE_SENSOR');
    along_beams = inCell(avail_dimensions, 'DIST_ALONG_BEAMS');

    if ~along_height && ~along_beams
        reason{end + 1} = 'Missing adcp bin dimensions';
    end

    time = IMOS.get_data(sample_data.dimensions, 'TIME');

    if isempty(time)
        reason{end + 1} = 'No TIME dimension.';
    end

    if along_height
        bin_dist = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
    elseif along_beams
        bin_dist = IMOS.get_data(sample_data.dimensions, 'DIST_ALONG_BEAMS');
    else
        bin_dist = [];
    end

    if isempty(bin_dist)
        reason{end + 1} = 'No bin distance dimensions.';
    end

catch
    reason{end + 1} = 'No dimensions in dataset.';
end

try
    idepth = IMOS.get_data(sample_data.variables, 'DEPTH');

    if isempty(idepth)
        reason{end + 1} = 'no DEPTH variable.';
    end

catch
    reason{end + 1} = 'No variables in dataset.';
end

bathy = IMOS.meta.site_bathymetry(sample_data);

if isempty(bathy)
    reason{end + 1} = 'no bathymetry metadata.';
end

beam_face_config = IMOS.meta.beam_face_config(sample_data);

if ~strcmpi(beam_face_config, 'up') && ~strcmpi(beam_face_config, 'down')
    reason{end + 1} = 'unknown ADCP beam face config or inconsistent sensor height values.';
end

if isempty(reason)
    bool = true;
else
    bool = false;
end

end
