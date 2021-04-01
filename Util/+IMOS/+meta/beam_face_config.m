function [beam_face_config] = beam_face_config(sample_data)
% function [beam_face_config] = beam_face_config(sample_data)
%
% Get the beam face config of an ADCP.
%
% Inputs:
%
% sample_data [struct] - the toolbox dataset.
%
% Outputs:
%
% beam_face_config [char] - 'up','down' or empty.
%
% Example:
%
% %basic usage
%
%
% author: hugo.oliveira@utas.edu.au
%
try
    beam_face_config = sample_data.meta.adcp_info.beam_face_config;
	return
catch
	try
		bin_dist = IMOS.get_data(sample_data.dimensions,'HEIGHT_ABOVE_SENSOR');
	catch
		try
			bin_dist = IMOS.get_data(sample_data.dimensions,'DIST_ALONG_BEAMS');
		catch
			beam_face_config = '';
			return
		end
	end
    if all(bin_dist>0)
        beam_face_config = 'up';
    elseif all(bin_dist<0)
        beam_face_config = 'down';
    else
        beam_face_config = '';
    end
end

end
