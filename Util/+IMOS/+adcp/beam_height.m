function [bheight] = beam_height(height_above_sensor)
% function [bheight] = beam_height(height_above_sensor)
%
% Compute the beam height from an ADCP.
%
% Inputs:
%
% height_above_sensor[numeric] - the bin centre distance from
% the transducer face.
%
% Outputs:
%
% bheight - the total beam height
%
% Example:
%
% %basic usage
% x = IMOS.adcp.beam_height([-10,-20,-30]);
% assert(x==35)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1,1)

if isempty(height_above_sensor)
	bheight = [];
	return
end

bheight = abs(height_above_sensor(end)) + 0.5 .* ( abs(height_above_sensor(end)) - abs(height_above_sensor(end-1)));

end
