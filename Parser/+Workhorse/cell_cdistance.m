function [cdistance] = cell_cdistance(first_bin_cdist, cell_length, num_cells, beam_face_config)
% function cell_cdistance(first_bin_cdist,cell_length,num_cells,beam_face_config)
%
% Compute the distance between the ADCP tranducer face and the beam cell centres.
%
% Inputs:
%
% first_bin_cdist [double] (singleton) - the distance, in cm, from the adcp tranducer face and the middle of the first cell.
% cell_length [double] (singleton) - the distance, in cm, between cell centres.
% num_cells [double] (singleton) - the total number of cells.
% beam_face_config [char] - 'up' or 'down'.
%
% Outputs:
%
% cdistance [double] (num_cells x 1) - the centre distance along the sensor in cm.
%
% Example:
%
% first_bin_cdist = 500.;
% cell_length = 100.;
% num_cells = 20;
% d = Workhorse.cell_cdistance(first_bin_cdist,cell_length,num_cells,'up');
% assert(d(1)==first_bin_cdist)
% assert(d(2)==first_bin_cdist+cell_length)
% assert(d(3)==first_bin_cdist+2*cell_length)
% assert(d(end)==first_bin_cdist+(num_cells-1)*cell_length)
%
% % Down facing is negative
% d = Workhorse.cell_cdistance(first_bin_cdist,cell_length,num_cells,'down');
% assert(all(sign(d)==-1))
%
narginchk(4, 4)

if strcmpi(beam_face_config, 'down')
    dir = -1;
else
    dir = 1;
end

% note this is actually distance between the ADCP's transducers and the
% middle of each cell, ignoring any binSize variation.
cdistance = dir * (first_bin_cdist: ...
    cell_length: ...
    first_bin_cdist + (num_cells - 1) * cell_length)';

end
