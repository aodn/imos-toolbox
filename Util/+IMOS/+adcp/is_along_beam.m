function [bool] = is_along_beam(sample_data)
% function [bool] = is_along_beam(sample_data)
%
% Check if a dataset is defined along beam coordinates.
% An along_beam dataset is one without the
% `HEIGHT_ABOVE_SENSOR` dimension.
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
% assert(~IMOS.adcp.is_along_beam(x));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)

avail_dims = IMOS.get(sample_data.dimensions,'name');
bool = ~inCell(avail_dims,'HEIGHT_ABOVE_SENSOR');

end
