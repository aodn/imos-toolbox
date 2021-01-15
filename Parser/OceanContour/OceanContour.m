classdef OceanContour
    %classdef OceanContour
    %
    % This is a class containing methods that defines several
    % fields and functions related to the OceanContour Parser.
    % This includes utility functions and variable/attribute
    % mappings to the toolbox structures.
    %
    % author: hugo.oliveira@utas.edu.au
    %
    %TODO: Design metadata typecasting.
    properties (Constant)
        beam_angles = struct('Signature250', 20, 'Signature500', 25, 'Signature1000', 25);
    end

    methods (Static)

        function metaname = build_meta_attr_midname(group_name)
            %function metaname = build_meta_attr_midname(group_name)
            %
            % Generate the middle name for global attributes given
            % a group name.
            %
            % Input:
            %
            % group_name - the fieldname or netcdf group name.
            %
            % Output:
            %
            % metaname - the mid/partial metadata attribute name string.
            %
            % Example:
            %
            % midname = OceanContour.build_meta_attr_midname('Avg');
            % assert(strcmp(midname,'avg'))
            % midname = OceanContour.build_meta_attr_midname('burstAltimeter');
            % assert(strcmp(midname,'burstAltimeter'))
            %
            if ~ischar(group_name)
                errormsg('first argument is not a string')
            end

            metaname = [lower(group_name(1)) group_name(2:end)];
        end

        function attname = build_instrument_name(group_name, var_name)
            %function attname = build_instrument_name(group_name,var_name)
            %
            % Generate instrument tokens for the attribute names
            % for in OceanContour files.
            %
            % The token is a three part string:
            % part1 - "Instrument" string, followed
            % part2 -  group/dataset name (with the first  letter lower)
            % part3 - the "variable" token/name.
            %
            % Inputs:
            %
            % group_name [str] - the dataset group (field) name
            % var_name [str] - the variable name (last token).
            %
            % Output:
            % attname [str] - the attribute name.
            %
            % Example:
            % name = OceanContour.build_instrument_name('Avg', 'coordSystem');
            % assert(strcmpi(name,'Instrument_avg_coordSystem'))
            %
            %
            % author: hugo.oliveira@utas.edu.au
            %
            narginchk(2, 2)

            if ~ischar(group_name)
                errormsg('first argument is not a string')
            elseif ~ischar(var_name)
                errormsg('second argument is not a string')
            end

            meta_attr_midname = OceanContour.build_meta_attr_midname(group_name);
            attname = ['Instrument_' meta_attr_midname '_' var_name];
        end

        function [ucur_name, vcur_name, heading_name] = build_magnetic_variables(custom_magnetic_declination)
            %function attname = build_magnetic_variables(custom_magnetic_declination)
            %
            % Generate VAR or VAR_MAG toolbox variable style names
            % based on provided magnetic declination info.
            %
            narginchk(1, 1)

            if ~islogical(custom_magnetic_declination)
                errormsg('build_magnetic_variables: first argument is not a logical')
            end

            if custom_magnetic_declination
                %TODO: This is probably unecessary
                %I believe OceanContourDouble-check if OceanContour will change variable names if custom magnetic declination is used.
                warning('%s: Assigning non ENU Velocities to ENU variables. Verify the magnetic declination angles.')
                ucur_name = 'UCUR_MAG';
                vcur_name = 'VCUR_MAG';
                heading_name = 'HEADING_MAG';
            else
                ucur_name = 'UCUR';
                vcur_name = 'VCUR';
                heading_name = 'HEADING';
            end

        end

        function verify_mat_groups(matdata)
            %just raise a proper error for invalid OceanContour mat files.
            try
                matdata.Config;
            catch
                errormsg('%s do not contains the ''Config'' metadata fieldname', filename)
            end

            ngroups = numel(fieldnames(matdata));

            if ngroups < 2
                errormsg('%s do not contains any data fieldname', fielname)
            end

        end

        function verify_netcdf_groups(info)
            %just raise a proper error for invalid OceanContour netcdf groups.
            try
                assert(strcmp(info.Groups(1).Name, 'Config'))
                assert(strcmp(info.Groups(2).Name, 'Data'))
            catch
                errormsg('contains an invalid OceanContour structure. please report this error with your data file: %s', filename)
            end

        end

        function warning_failed(failed_items, filename)
            %just raise a proper warning for failed variable reads
            for k = 1:numel(failed_items)
                warning('%s: Couldn''t read variable `%s` in %s', mfilename, failed_items{k}, filename)
            end

        end


        function [attmap] = get_attmap(ftype, group_name)
            %function [attmap] = get_attmap(ftype, group_name)
            %
            % Generate dynamical attribute mappings based on
            % the dataset group name.
            %
            % Inputs:
            %
            % ftype [str] - the file type. 'mat' or 'netcdf';
            % group_name [str] - the OceanContour dataset group name.
            %
            % Outputs:
            %
            % attmap [struct[str,str]] - mapping between imos attributes
            %                           & OceanContour attributes.
            %
            %
            % Example:
            %
            % %basic usage
            % attmap = OceanContour.get_attmap('Avg');
            % fnames = fieldnames(attmap);
            % assert(contains(fnames,'instrument_model'))
            % original_name =attmap.instrument_model;
            % assert(strcmp(original_name,'Instrument_instrumentName'));
            %
            % author: hugo.oliveira@utas.edu.au
            %

            if ~ischar(ftype)
                errormsg('First argument is not a string')
            elseif ~strcmpi(ftype, 'mat') && ~strcmpi(ftype, 'netcdf')
                errormsg('First argument %s is an invalid ftype. Accepted file types are ''mat'' and ''netcdf''.', ftype)
            elseif ~ischar(group_name)
                errormsg('Second argument is not a string')
            end

            attmap = struct();

            meta_attr_midname = OceanContour.build_meta_attr_midname(group_name);

            attmap.('instrument_model') = 'Instrument_instrumentName';
            attmap.('beam_angle') = 'DataInfo_slantAngles';
            attmap.('beam_interval') = 'DataInfo_slantAngles';
            attmap.('coordinate_system') = OceanContour.build_instrument_name(group_name, 'coordSystem');
            attmap.('nBeams') = OceanContour.build_instrument_name(group_name, 'nBeams');
            attmap.('activeBeams') = OceanContour.build_instrument_name(group_name, 'activeBeams'); %no previous name
            attmap.('magDec') = 'Instrument_user_decl';

            if strcmpi(ftype, 'mat')
                attmap.('instrument_serial_no') = 'Instrument_serialNumberDoppler';
                attmap.('binSize') = OceanContour.build_instrument_name(group_name, 'cellSize');
            end

            %custom & dynamical fields
            attmap.(['instrument_' meta_attr_midname '_enable']) = OceanContour.build_instrument_name(group_name, 'enable');

            switch meta_attr_midname
                case 'avg'
                    attmap.('instrument_avg_interval') = OceanContour.build_instrument_name(group_name, 'averagingInterval');
                    attmap.('instrument_sample_interval') = OceanContour.build_instrument_name(group_name, 'measurementInterval');
                    %TODO: need a more complete file to test below below
                case 'burst'
                    attmap.('instrument_burst_interval') = OceanContour.build_instrument_name(group_name, 'burstInterval');
                case 'bursthr'
                    attmap.('instrument_bursthr_interval') = OceanContour.build_instrument_name(group_name, 'burstHourlyInterval');
                case 'burstAltimeter'
                    attmap.('instrument_burstAltimeter_interval') = OceanContour.build_instrument_name(group_name, 'burstAltimeterInterval');
                case 'burstRawAltimeter'
                    attmap.('instrument_burstRawAltimeter_interval') = OceanContour.build_instrument_name(group_name, 'burstRawAltimeterInterval');
            end

        end

        function [varmap] = get_varmap(ftype, group_name, nbeams, custom_magnetic_declination)
            %function [varmap] = get_varmap(ftype, group_name,nbeams,custom_magnetic_declination)
            %
            % Generate dynamical variable mappings for a certain
            % group of variables, given the number of beams and if custom
            % magnetic adjustments were made.
            %
            % Inputs:
            %
            % ftype [str] - The file type. 'mat' or 'netcdf'.
            % group_name [str] - the OceanContour dataset group name.
            % nbeams [double] - The nbeams used on the dataset.
            % custom_magnetic_declination [logical] - true for custom
            %                                         magnetic values.
            %
            % Outputs:
            %
            % vttmap [struct[str,str]] - mapping between imos variables
            %                           & OceanContour variables.
            %
            %
            % Example:
            %
            % %basic usage
            %
            % varmap = OceanContour.get_attmap('Avg',4,False);
            % assert(strcmp(attmap.WCUR_2,'Vel_Up2'));
            %
            % % nbeams == 3
            % varmap = OceanContour.get_varmap('Avg',3,False);
            % f=false;try;varmap.WCUR_2;catch;f=true;end
            % assert(f)
            %
            % % custom magdec - may change with further testing
            % varmap = OceanContour.get_varmap('Avg',4,True);
            % assert(strcmp(varmap.UCUR_MAG,'Vel_East'))
            %
            %
            % author: hugo.oliveira@utas.edu.au
            %
            narginchk(4, 4)

            if ~ischar(ftype)
                errormsg('First argument is not a string')
            elseif ~strcmpi(ftype, 'mat') && ~strcmpi(ftype, 'netcdf')
                errormsg('First argument %s is an invalid ftype. Accepted file types are ''mat'' and ''netcdf''.', ftype)
            elseif ~ischar(group_name)
                errormsg('First argument is not a string')
            elseif ~isscalar(nbeams)
                errormsg('Second argument is not a scalar')
            elseif ~islogical(custom_magnetic_declination)
                errormsg('Third argument is not logical')
            end

            is_netcdf = strcmpi(ftype, 'netcdf');
            [ucur_name, vcur_name, heading_name] = OceanContour.build_magnetic_variables(custom_magnetic_declination);

            varmap = struct();
            varmap.('binSize') = 'CellSize';
            varmap.('TIME') = 'MatlabTimeStamp';

            if is_netcdf
                varmap.('instrument_serial_no') = 'SerialNumber';
                %TODO: reinforce uppercase at first letter? nEed to see more files.
                varmap.('HEIGHT_ABOVE_SENSOR') = [group_name 'VelocityENU_Range'];
                %TODO: Handle magnetic & along beam cases.
                %varmap.('DIST_ALONG_BEAMS') = [group_name 'Velocity???_Range'];
                %TODO: evaluate if when magnetic declination is provided, the
                %velocity fields will be corrected or not (as well as any rename/comments added).
                varmap.(ucur_name) = 'Vel_East';
                varmap.(vcur_name) = 'Vel_North';
                varmap.(heading_name) = 'Heading';
                varmap.('WCUR') = 'Vel_Up1';
                varmap.('ABSI1') = 'Amp_Beam1';
                varmap.('ABSI2') = 'Amp_Beam2';
                varmap.('ABSI3') = 'Amp_Beam3';
                varmap.('CMAG1') = 'Cor_Beam1';
                varmap.('CMAG2') = 'Cor_Beam2';
                varmap.('CMAG3') = 'Cor_Beam3';

                if nbeams > 3
                    varmap.('WCUR_2') = 'Vel_Up2';
                    varmap.('ABSI4') = 'Amp_Beam4';
                    varmap.('CMAG4') = 'Cor_Beam4';
                end

            else
                %instrument_serial_no is on metadata for matfiles.
                varmap.('HEIGHT_ABOVE_SENSOR') = 'Range';
                varmap.(ucur_name) = 'VelEast';
                varmap.(vcur_name) = 'VelNorth';
                varmap.(heading_name) = 'Heading';
                varmap.('WCUR') = 'VelUp1';
                varmap.('ABSI1') = 'AmpBeam1';
                varmap.('ABSI2') = 'AmpBeam2';
                varmap.('ABSI3') = 'AmpBeam3';
                varmap.('CMAG1') = 'CorBeam1';
                varmap.('CMAG2') = 'CorBeam2';
                varmap.('CMAG3') = 'CorBeam3';

                if nbeams > 3
                    varmap.('WCUR_2') = 'VelUp2';
                    varmap.('ABSI4') = 'AmpBeam4';
                    varmap.('CMAG4') = 'CorBeam4';
                end

            end

            varmap.('TEMP') = 'WaterTemperature';
            varmap.('PRES_REL') = 'Pressure';
            varmap.('SSPD') = 'SpeedOfSound';
            varmap.('BAT_VOLT') = 'Battery';
            varmap.('PITCH') = 'Pitch';
            varmap.('ROLL') = 'Roll';
            varmap.('ERROR') = 'Error';
            varmap.('AMBIG_VEL') = 'Ambiguity';
            varmap.('TRANSMIT_E') = 'TransmitEnergy';
            varmap.('NOMINAL_CORR') = 'NominalCor';

        end

        function [imap] = get_importmap(nbeams, custom_magnetic_declination)
            %function [imap] = get_importmap(custom_magnetic_declination)
            %
            % Return default variables to import from the OceanContour files.
            %
            % Inputs:
            %
            % nbeams [scalar] - the number of ADCP beams.
            % custom_magnetic_declination [logical] - true for custom
            %                                         magnetic values.
            %
            % Outputs:
            %
            % imap [struct[cell]] - Struct with different variables
            %                       classes to import
            %
            %
            % Example:
            %
            % %basic usage
            % imap = OceanContour.get_importmap(False);
            % assert(inCell(imap.all_variables,'PITCH'))
            % assert(inCell(imap.all_variables,'ROLL'))
            %
            % author: hugo.oliveira@utas.edu.au
            %
            narginchk(2, 2)

            if ~isscalar(nbeams)
                errormsg('First argument is not a scalar')
            elseif ~islogical(custom_magnetic_declination)
                errormsg('Second argument is not a logical')
            end

            imap = struct();
            [ucur_name, vcur_name, heading_name] = OceanContour.build_magnetic_variables(custom_magnetic_declination);

            ENU = struct();

            ENU.one_dimensional = {'TEMP', 'PRES_REL', 'SSPD', 'BAT_VOLT', 'PITCH', 'ROLL', heading_name, 'ERROR', 'AMBIG_VEL', 'TRANSMIT_E', 'NOMINAL_CORR'};
            ENU.velocity_variables = {ucur_name, vcur_name, 'WCUR'};
            ENU.beam_amplitude_variables = {'ABSI1', 'ABSI2', 'ABSI3'};
            ENU.correlation_variables = {'CMAG1', 'CMAG2', 'CMAG3'};

            if nbeams > 3
                ENU.velocity_variables = [ENU.velocity_variables, 'WCUR_2'];
                ENU.beam_amplitude_variables = [ENU.beam_amplitude_variables 'ABSI4'];
                ENU.correlation_variables = [ENU.correlation_variables 'CMAG4'];
            end

            ENU.two_dimensional = [ENU.velocity_variables, ENU.beam_amplitude_variables];
            ENU.all_variables = [ENU.one_dimensional, ENU.two_dimensional];

            %TODO: Implement Non-ENU cases.

            imap.('ENU') = ENU;

        end

        function [sample_data] = readOceanContourFile(filename)
            % function [sample_data] = readOceanContourFile(filename)
            %
            % Read an OceanContour netcdf or mat file and convert fields
            % to the matlab toolbox structure. Variables are read
            % as is.
            %
            % Supported Innstruments: Nortek ADCP Signatures.
            %
            % The Ocean contour software write nested netcdf4 groups:
            % > root
            %    |
            % {root_groups}
            %    | -> Config ["global" file metadata only]
            %    | -> Data [file datasets leaf]
            %          |
            %       {data_groups}
            %          | -> Avg [data+metadata]
            %          | -> ... [data+metadata]
            %
            % Or a flat mat file:
            % > root
            %    |
            %{data_groups}
            %      | -> [dataset-name] [data]
            %      | -> Config [metadata]
            %
            %
            % Inputs:
            %
            % filename [str] - the filename.
            %
            % Outputs:
            %
            % sample_data - the toolbox structure.
            %
            % Example:
            %
            % %read from netcdf
            % file = [toolboxRootPath 'data/testfiles/netcdf/Nortek/OceanContour/Signature/s500_enu_avg.nc'];
            % [sample_data] = readOceanContour(file);
            % assert(strcmpi(sample_data{1}.meta.instrument_model,'Signature500'))
            % assert(isequal(sample_data{1}.meta.instrument_avg_interval,60))
            % assert(isequal(sample_data{1}.meta.instrument_sample_interval,600))
            % assert(strcmpi(sample_data{1}.meta.coordinate_system,'ENU'))
            % assert(isequal(sample_data{1}.meta.nBeams,4))
            % assert(strcmpi(sample_data{1}.dimensions{2}.name,'HEIGHT_ABOVE_SENSOR'))
            % assert(~isempty(sample_data{1}.variables{end}.data))
            %
            % % read from matfile
            % file = [toolboxRootPath 'data/testfiles/mat/Nortek/OceanContour/Signature/s500_enu_avg.mat'];
            % [sample_data] = readOceanContour(file);
            % assert(strcmpi(sample_data{1}.meta.instrument_model,'Signature500'))
            % assert(isequal(sample_data{1}.meta.instrument_avg_interval,60))
            % assert(isequal(sample_data{1}.meta.instrument_sample_interval,600))
            % assert(strcmpi(sample_data{1}.meta.coordinate_system,'ENU'))
            % assert(isequal(sample_data{1}.meta.nBeams,4))
            % assert(strcmpi(sample_data{1}.dimensions{2}.name,'HEIGHT_ABOVE_SENSOR'))
            % assert(~isempty(sample_data{1}.variables{end}.data))
            %
            %
            % author: hugo.oliveira@utas.edu.au
            %
            narginchk(1, 1)

            try
                info = ncinfo(filename);
                ftype = 'netcdf';

            catch

                try
                    matdata = load(filename);
                    ftype = 'mat';
                catch
                    errormsg('%s is not a mat or netcdf file', filename)
                end

            end

            is_netcdf = strcmpi(ftype, 'netcdf');

            if is_netcdf
                OceanContour.verify_netcdf_groups(info);
                file_metadata = nc_flat(info.Groups(1).Attributes, false);
                data_metadata = nc_flat(info.Groups(2).Groups, false);

                ncid = netcdf.open(filename);
                root_groups = netcdf.inqGrps(ncid);
                data_group = root_groups(2);

                dataset_groups = netcdf.inqGrps(data_group);
                get_group_name = @(x)(netcdf.inqGrpName(x));

            else
                OceanContour.verify_mat_groups(matdata);
                file_metadata = matdata.Config;
                matdata = rmfield(matdata, 'Config'); %mem optimisation.

                dataset_groups = fieldnames(matdata);
                get_group_name = @(x)(getindex(split(x, '_Data'), 1));

            end

            n_datasets = numel(dataset_groups);
            sample_data = cell(1, n_datasets);

            for k = 1:n_datasets

                % start by loading preliminary information into the metadata struct, so we
                % can define the variable names and variables to import.
                meta = struct();

                group_name = get_group_name(dataset_groups);
                meta_attr_midname = OceanContour.build_meta_attr_midname(group_name);

                %load toolbox_attr_names:file_attr_names dict.
                att_mapping = OceanContour.get_attmap(ftype, group_name);

                %access pattern - use lookup based on expected names,
                get_att = @(x)(file_metadata.(att_mapping.(x)));

                nBeams = double(get_att('nBeams'));

                try
                    activeBeams = double(get_att('activeBeams'));
                catch
                    activeBeams = Inf;
                end

                meta.nBeams = min(nBeams, activeBeams);

                try
                    assert(meta.nBeams == 4);
                    %TODO: support variable nBeams. need more files.
                catch
                    errormsg('Only 4 Beam ADCP are supported. %s got %d nBeams', filename, meta.nBeams)
                end

                meta.magDec = get_att('magDec');
                custom_magnetic_declination = logical(meta.magDec);

                %Now that we know some preliminary info, we can load the variable
                % name mappings and the list of variables to import.
                var_mapping = OceanContour.get_varmap(ftype, group_name, nBeams, custom_magnetic_declination);
                import_mapping = OceanContour.get_importmap(nBeams, custom_magnetic_declination);

                %subset the global metadata fields to only the respective group.
                dataset_meta_id = ['_' meta_attr_midname '_'];
                [~, other_datasets_meta_names] = filterFields(file_metadata, dataset_meta_id);
                dataset_meta = rmfield(file_metadata, other_datasets_meta_names);

                %load extra metadata and unify the variable access pattern into
                % the same function name.
                if is_netcdf
                    meta.dim_meta = data_metadata.(group_name).Dimensions;
                    meta.var_meta = data_metadata.(group_name).Variables;
                    gid = dataset_groups(k);
                    get_var = @(x)(nc_get_var(gid, var_mapping.(x)));
                else
                    fname = getindex(dataset_groups, k);
                    get_var = @(x)(transpose(matdata.(fname).(var_mapping.(x))));
                end

                meta.featureType = '';
                meta.instrument_make = 'Nortek';
                meta.instrument_model = get_att('instrument_model');

                if is_netcdf
                    inst_serial_no = unique(get_var('instrument_serial_no'));
                else
                    %serial no is at metadata/Config level in the mat files.
                    instr_serial_no = unique(get_att('instrument_serial_no'));
                end

                try
                    assert(numel(inst_serial_no) == 1)
                catch
                    errormsg('Multi instrument serial numbers found in %s.', filename)
                end
                meta.instrument_serial_no = num2str(inst_serial_no);

                try
                    assert(contains(meta.instrument_model, 'Signature'))
                    %TODO: support other models. need more files.
                catch
                    errormsg('Only Signature ADCPs are supported.', filename)
                end

                default_beam_angle = OceanContour.beam_angles.(meta.instrument_model);
                instrument_beam_angles = single(get_att('beam_angle'));
                try
                    dataset_beam_angles = instrument_beam_angles(1:meta.nBeams);
                    assert(isequal(unique(dataset_beam_angles), default_beam_angle))
                    %TODO: workaround for inconsistent beam_angles. need more files.
                catch
                    errormsg('Inconsistent beam angle/Instrument information in %s', filename)
                end
                meta.beam_angle = default_beam_angle;

                meta.('instrument_sample_interval') = single(get_att('instrument_sample_interval'));

                mode_sampling_duration_str = ['instrument_' meta_attr_midname '_interval'];
                meta.(mode_sampling_duration_str) = get_att(mode_sampling_duration_str);

                time = get_var('TIME');

                try
                    actual_sample_interval = single(mode(diff(time)) * 86400.);
                    assert(isequal(meta.('instrument_sample_interval'), actual_sample_interval))
                catch
                    expected = meta.('instrument_sample_interval');
                    got = actual_sample_interval;
                    errormsg('Inconsistent instrument sampling interval in %s . Metadata is set to %d, while time variable indicates %d', filename, expected, got);
                end

                meta.coordinate_system = get_att('coordinate_system');

                try
                    assert(strcmp(meta.coordinate_system, 'ENU'))
                    %TODO: support other CS. need more files.
                catch
                    errormsg('Unsuported coordinates. %s contains non-ENU data.', filename)
                end

                z = get_var('HEIGHT_ABOVE_SENSOR');

                try
                    assert(all(z > 0));
                catch
                    errormsg('invalid VelocityENU_Range in %s', filename)
                    %TODO: plan any workaround for diff ranges. files!?
                end

                meta.binSize = unique(get_var('binSize'));

                try
                    assert(numel(meta.binSize) == 1)
                catch
                    errormsg('Nonuniform CellSizes in %s', mfilename, filename)
                    %TODO: plan any workaround for nonuniform cells. need files.
                end

                meta.file_meta = file_metadata;
                meta.dataset_meta = dataset_meta;

                dimensions = IMOS.templates.dimensions.adcp_remapped;
                dimensions{1}.data = time;
                dimensions{1}.comment = 'time imported from matlabTimeStamp variable';
                dimensions{2}.data = z;
                dimensions{2}.comment = 'height imported from VelocityENU_Range';

                switch meta.coordinate_system
                    case 'ENU'
                        onedim_vnames = import_mapping.('ENU').one_dimensional;
                        twodim_vnames = import_mapping.('ENU').two_dimensional;
                    otherwise
                        errormsg('%s coordinates found in %s is not implemented yet', filename, adcp_data_type)
                end

                onedim_vcoords = [dimensions{1}.name ' LATITUDE LONGITUDE ' 'NOMINAL_DEPTH']; %TODO: point to Pressure/Depth via CF-conventions
                onedim_vtypes = IMOS.cellfun(@getIMOSType, onedim_vnames);
                [onedim_vdata, failed_items] = IMOS.cellfun(get_var, onedim_vnames);

                if ~isempty(failed_items)
                    OceanContour.warning_failed(failed_items, filename)
                end

                twodim_vcoords = [dimensions{1}.name ' LATITUDE LONGITUDE ' dimensions{2}.name];
                twodim_vtypes = IMOS.cellfun(@getIMOSType, twodim_vnames);
                [twodim_vdata, failed_items] = IMOS.cellfun(get_var, twodim_vnames);

                if ~isempty(failed_items)
                    OceanContour.warning_failed(failed_items, filename)
                end

                %TODO: Implement unit conversions monads.
                variables = [...
                            IMOS.featuretype_variables('timeSeries'), ...
                            IMOS.gen_variables(dimensions, onedim_vnames, onedim_vtypes, onedim_vdata, 'coordinates', onedim_vcoords), ...
                            IMOS.gen_variables(dimensions, twodim_vnames, twodim_vtypes, twodim_vdata, 'coordinates', twodim_vcoords), ...
                            ];

                dataset = struct();
                dataset.toolbox_input_file = filename;
                dataset.toolbox_parser = mfilename;
                dataset.netcdf_group_name = group_name;
                dataset.meta = meta;
                dataset.dimensions = dimensions;
                dataset.variables = variables;

                sample_data{k} = dataset;
            end

        end

    end

end
