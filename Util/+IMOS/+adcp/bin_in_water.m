function [wb, fbin] = bin_in_water(idepth,bin_dist,beam_face_config,bathy)
% function [wb,fbin] = bin_in_water(idepth,bin_dist,beam_face_config,bathy)
%
% Find the ADCP water bins and the 
% further bin that is within the water envelope:
%
%    Dowward          out >   x
%    Looking          out >   x
% -------------     --------------zeta(t,x,y)
%                           Fbin
%      vvvv  <-- idepth      wb
%       wb                   wb
%       wb                   wb
%       wb                  ^^^^  <-- idepth
%      Fbin
% -------------     ------------- h(x,y)
% out > x                  Upward
% out > x                  Looking
%
% Inputs:
%
% idepth [double] [1x1 or Nx1] - the instrument depth.
% bin_dist [double] [Mx1] -  the adcp bin centre distances.
% beam_face_config [str] - the adcp face config ["up" or "down"]
% bathy [double] [1x1] - the local bathymetry (required for "down" measurements).
%
% Outputs:
%
% wb [logical] TxZ - the bins in the water envelope.
% fbin [array] 1xT - the last/further bin inside the envelope.
%
% Example:
%
% %basic usage - no bin in water
% idepth = 190*ones(100,1);
% beam_face_config = 'down';
% bin_dist = -1*(10:10:500)';
% bathy = 200;
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config,bathy);
% assert(~any(wb,'all'));
% assert(all(fbin==0));
%
% % one bin in water
% bathy = 210;
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config,bathy);
% assert(sum(wb,'all')==100);
% assert(all(fbin==1));
%
% % 10 bins in water
% bathy = 300;
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config,bathy);
% assert(sum(wb,'all')==1000); % 100*10
% assert(all(fbin==10));
%
% %upward
% beam_face_config = 'up';
% idepth = 10*ones(100,1);
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config);
% assert(sum(wb,'all')==0);
% assert(all(fbin==0));
%
% idepth = 20*ones(100,1);
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config);
% assert(sum(wb,'all')==100);
% assert(all(fbin==1));
%
% idepth = 110*ones(100,1);
% [wb,fbin] = IMOS.adcp.bin_in_water(idepth,bin_dist,beam_face_config);
% assert(sum(wb,'all')==1000); % 100*10
% assert(all(fbin==10));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(3,4);

if ~iscolumn(idepth) || isempty(idepth)
    errormsg('First argument is invalid. Instrument depth should be a non-empty column vector')
end
if ~iscolumn(bin_dist)
    errormsg('Second argument is invalid. ADCP bin distances should be a non-empty column vector')
end

upward_looking = strcmpi(beam_face_config,'up');
downward_looking = strcmpi(beam_face_config,'down');
if ~upward_looking && ~downward_looking
    errormsg('Third Argument is invalid. ADCP beam face config should be ''up'' or ''down''')
end
if downward_looking && nargin<4
    errormsg('Not enough arguments. Down-looking ADCPs requires an extra argument representing the local bathymetry.')
end

if nargin>3 && (isempty(bathy) || numel(bathy)~=1)
    errormsg('Fourth argument is invalid. Bathymetry should be a non-empty scalar.')
end

nz = numel(bin_dist);
bin_distance = reshape(abs(bin_dist), 1, nz);

%follow convention that depth is positive down.
if upward_looking
    visible_water_column_height = idepth; % + zeta
else
    if isempty(bathy)
        errormsg('No site_depth in for %s. Cannot estimate visible water column height.', sample_data.toolbox_input_file)
    end
    visible_water_column_height = bathy - idepth; % + zeta
end
wb = bin_distance < visible_water_column_height;

if nargout > 1
    fbin = sum(wb, 2);
end

end
