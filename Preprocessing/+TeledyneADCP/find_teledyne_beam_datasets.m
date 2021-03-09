function cind = find_teledyne_beam_datasets(sample_data,key_dimension)
%function [cind] = find_teledyne_beam_datasets(sample_data,key_dimension)
%
% Detect RDI ADCP Teledyne datasets that are able to be
% converted from beam to ENU coordinates.
%
% This inspect dimensions, variables, and
% metadata attributes.
%
% Inputs:
%
% sample_data [cell{struct}] - A cell with all samples.
% key_dimension [string] - Compulsory dimension name to be matched in 
% a variable
%                        - Default: 'HEIGHT_ABOVE_SENSOR'
%
% Outputs:
%
% cind [int] - The valid indexes where data can be converted.
%
%
% Examples:
%
% varnames = {'VEL1', 'VEL2', 'VEL3', 'VEL4', 'PITCH', 'ROLL', 'HEADING_MAG'};
% dimnames = {'TIME','HEIGHT_ABOVE_SENSOR'};
% coords = 'TIME Y X HEIGHT_ABOVE_SENSOR';
% d = IMOS.gen_dimensions('timeSeries',2,dimnames);
% v = IMOS.gen_variables(d,varnames,{},{},'coordinates',coords);
% m = struct('instrument_make','Teledyne RDI','compass_correction_applied',0);
% m.adcp_info.coords.frame_of_reference='beam';
% s.dimensions = d;
% s.variables = v;
% s.meta = m;
% assert(isequal(TeledyneADCP.find_teledyne_beam_datasets({s,s,s}),[1,2,3]));
%
% %invalid
% s2 = s;
% s2.variables = s2.variables(1:4);
% assert(isempty(TeledyneADCP.find_teledyne_beam_datasets({s2})))
% assert(TeledyneADCP.find_teledyne_beam_datasets({s2,s,s2})==2)
%
% %do not touch earth coords
% s2 = s;
% s2.meta.adcp_info.coords.frame_of_reference = 'earth';
% assert(isempty(TeledyneADCP.find_teledyne_beam_datasets({s2})));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(1, 2)
if nargin==1
    key_dimension = 'HEIGHT_ABOVE_SENSOR';
end

required_dimensions = {key_dimension};
ndatasets = length(sample_data);
whereind = zeros(1, ndatasets, 'logical');

for k = 1:ndatasets
    dataset = sample_data{k};
    try
        vnames = IMOS.get(dataset.variables, 'name');
        dnames = IMOS.get(dataset.dimensions, 'name');
        not_teledyne = ~strcmpi(dataset.meta.instrument_make, 'Teledyne RDI');
        no_compass_metadata_available = ~isfield(dataset.meta, 'compass_correction_applied');
        not_in_beam_coordinates = ~strcmpi(dataset.meta.adcp_info.coords.frame_of_reference,'beam');
    catch
        continue
    end

    if not_teledyne || no_compass_metadata_available || not_in_beam_coordinates
        continue
    end

    no_magnetic_correction = dataset.meta.compass_correction_applied == 0;

    if no_magnetic_correction
        required_variables = {'VEL1', 'VEL2', 'VEL3', 'VEL4', 'PITCH', 'ROLL', 'HEADING_MAG'};
    else
        required_variables = {'VEL1', 'VEL2', 'VEL3', 'VEL4', 'PITCH', 'ROLL', 'HEADING'};
    end

    invalid_content = ~isinside(vnames, required_variables) || ~isinside(dnames, required_dimensions);
    
    if invalid_content
        continue
    end

    [~, beam_dim_index] = inCell(dnames, key_dimension);
    s = IMOS.as_named_struct(dataset.variables);

    for l = 1:numel(required_variables)
        vname = required_variables{l};

        try
            not_beam_dim = ~isequal(s.(vname).dimensions{2}, beam_dim_index);
            not_beam_coords = ~contains(s.(vname).coordinates, key_dimension);
            invalid_beam_var = not_beam_dim || not_beam_coords;
            if invalid_beam_var
                continue
            end
        catch
            continue
        end

    end

    whereind(k) = true;
end

cind = find(whereind);
end
