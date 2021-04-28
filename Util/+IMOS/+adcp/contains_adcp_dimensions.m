function [bool,dname] = contains_adcp_dimensions(sample_data)
% function [bool,dname] = contains_adcp_dimensions(sample_data)
%
% Detect if the sample data contains adcp dimensions.
%
% Inputs:
%
% sample_data - toolbox struct.
%
% Outputs:
%
% bool - True or False for ADCP data.
% dname - the dimension associated with the transducer bins.
%
% Example:
%
% %basic usage
% z.dimensions = IMOS.gen_dimensions('adcp');
% [b,name] = IMOS.adcp.contains_adcp_dimensions(z);
% assert(b);
% assert(strcmpi(name,'DIST_ALONG_BEAMS'));
% z.dimensions{3}.name = 'HEIGHT_ABOVE_SENSOR';
% [b,name] = IMOS.adcp.contains_adcp_dimensions(z);
% assert(b);
% %HEIGHT is checked first.
% assert(strcmpi(name,'HEIGHT_ABOVE_SENSOR'));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 1)
bool = false;
dname = '';

avail_dimensions = IMOS.get(sample_data.dimensions, 'name');

height = 'HEIGHT_ABOVE_SENSOR';
beam = 'DIST_ALONG_BEAMS';

if inCell(avail_dimensions,height)
    dname = height;
    bool = true;
elseif inCell(avail_dimensions,beam)
    dname = beam;
    bool = true;
end

end
