classdef testadcpWorkhorseBeam2EarthPP < matlab.unittest.TestCase
	%
    % Test rotation of angles from Beam to Earth coordinates
    % Pre processign function.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)

        quartermaster_file = {fpath('v000/beam/1759001.000.reduced')};
    end

    methods (Test)

        function testCompareAgainstBecOriginalFile(test)
	
			%This mat file is one produced at commit hash 9efcff9b015c121407e3b95da31efe0cddd1da1b 
			% by calling:
			%sample_data = workhorseParse(fpath('v000/beam/1759001.000.reduced'));
			% Note that, despite the original code is supposedly to perform binmapping,
			% no actual bin mapping is performed, since in the binmap function within
			% rdiBeam2Earth, there is are reassignments to original data
			% (see line 180-190) of rdiBeam2Earth.m at the respective commit.
	        orig_data = load(fpath('v000/beam/1759001.000.reduced.enu_without_binmap.mat'));
            orig_enu = orig_data.sample_data;

            new_data = workhorseParse({test.quartermaster_file{1}}, '');
            new_enu = adcpWorkhorseVelocityBeam2EnuPP({new_data}, '');
			new_enu = new_enu{1};

			%adcpWorkhorseVelocityBeam2EnuPP works for both non-bin-mapped and bin-mapped variables.
			dim_names = IMOS.get(new_enu.dimensions,'name');
			assert(inCell(dim_names,'DIST_ALONG_BEAMS'))

			orig_var = IMOS.as_named_struct(orig_enu.variables);
			new_var = IMOS.as_named_struct(new_enu.variables);
			decrange = 3;
			velocity_vars = {'UCUR_MAG','VCUR_MAG','WCUR','ECUR'};
			for k=1:numel(velocity_vars)
				vname = velocity_vars{k};
				errmsg = sprintf('Variable %s differs by more than 1%',vname);
				[~,~,p] = isequal_tol(orig_var.(vname).data,new_var.(vname).data,decrange);
				assert(p>0.99,errmsg);

				assert(contains(new_var.(vname).comment,'adcpWorkhorseVelocityBeam2EnuPP.m'))
				assert(contains(new_var.(vname).comment,'has been calculated from velocity data in Beams coordinates using'))
			end

        end

		function testRotationAfterBinMapping(~,quartermaster_file)
            sample_data = workhorseParse({quartermaster_file}, '');
			original_varnames = IMOS.get(sample_data.variables,'name');
			assert(isinside(original_varnames,{'VEL1','VEL2','VEL3','VEL4'}));
			
			sample_data = adcpBinMappingPP({sample_data},'');
			assert(isfield(sample_data{1},'history'))
			assert(contains(sample_data{1}.history,'adcpBinMappingPP.m'))
		
			dim_names = IMOS.get(sample_data{1}.dimensions,'name');
			assert(~inCell(dim_names,'DIST_ALONG_BEAMS'))
			assert(inCell(dim_names,'HEIGHT_ABOVE_SENSOR'))

			sample_data = adcpWorkhorseVelocityBeam2EnuPP(sample_data,'');
			sample_data = sample_data{1};
			assert(isfield(sample_data,'history'))
			assert(contains(sample_data.history,'adcpWorkhorseVelocityBeam2EnuPP.m'))
			rotated_varnames = IMOS.get(sample_data.variables,'name');

			if sample_data.meta.compass_correction_applied
				complete = isinside(rotated_varnames,{'UCUR','VCUR','WCUR','ECUR'});
			else
				complete = isinside(rotated_varnames,{'UCUR_MAG','VCUR_MAG','WCUR','ECUR'});
			end
			assert(complete)
	    end
	end

end

function [path] = fpath(arg)
    path = [toolboxRootPath 'data/testfiles/Teledyne/workhorse/' arg];
end
