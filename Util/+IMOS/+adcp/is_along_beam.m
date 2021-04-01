function [bool] = is_along_beam(sample_data)
% function [bool] = is_along_beam(sample_data)
%
% Check if a dataset is defined along beam coordinates.
%
% Inputs:
%
% sample_data [struct] - a toolbox dataset.
%
% Outputs:
%
% bool - True if 'DIST_ALONG_BEAMS' is defined.
%
% Example:
%
% %basic usage
% x.dimensions = IMOS.gen_dimensions('adcp');
% assert(IMOS.adcp.is_along_beam(x));
% x.dimensions{3}.name = 'HEIGHT_ABOVE_SENSOR';
% assert(IMOS.adcp.is_along_beam(x));
% x.dimensions{2}.name = 'HEIGHT_ABOVE_SENSOR';
% assert(~IMOS.adcp.is_along_beam(x));
%
%
% author: hugo.oliveira@utas.edu.au
%
avail_dims = IMOS.get(sample_data.dimensions,'name');
bool = inCell(avail_dims,'DIST_ALONG_BEAMS');
end
