classdef testOceanContour < matlab.unittest.TestCase

    % Test Reading Nortek Signature files output by OceanContour software
    % with the OceanContour
    % function.
    %
    % author: laurent.besnard@utas.edu.au
    %
    % TODO: understand why fillValues for s500 and s1000 are different by a
    % factor 10
        

    properties (TestParameter)
        mode = {'timeSeries'};
        oceancontour_sig500_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/netcdf/Nortek/OceanContour/Signature/sig500']));
        oceancontour_sig1000_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/netcdf/Nortek/OceanContour/Signature/sig1000']));
    end

    methods (Test)

        function testOceanContourSig500(~, oceancontour_sig500_file)
            data = OceanContour.readOceanContourFile(oceancontour_sig500_file);
            assert(strcmp(data{1}.meta.instrument_model,'Signature500'));
            assert(strcmp(data{1}.meta.instrument_make,'Nortek'));
            assert(strcmp(data{1}.meta.coordinate_system,'ENU'));
            assert(data{1}.meta.beam_angle==25);
            assert(round(mean(data{1,1}.variables{1,5}.data)) == 19)  % TEMP var check
             
            tolerance = 0.001;
            assert(abs(min(data{1,1}.variables{1,16}.data(:,1)) - -32.7680) < tolerance);  % UCUR var check. fillvalue seems to be -32.7680
        end
        
        function testOceanContourSig1000(~, oceancontour_sig1000_file)
            data = OceanContour.readOceanContourFile(oceancontour_sig1000_file);
            assert(strcmp(data{1}.meta.instrument_model,'Signature1000'));
            assert(strcmp(data{1}.meta.instrument_make,'Nortek'));
            assert(strcmp(data{1}.meta.coordinate_system,'ENU'));
            assert(data{1}.meta.beam_angle==25);
            assert(round(mean(data{1,1}.variables{1,5}.data)) == 20)  % temperature var check
            
            tolerance = 0.001;
            assert(abs(min(data{1,1}.variables{1,16}.data(:,1)) - -3.27680) < tolerance);  % UCUR var check. fillvalue seems to be -3.27680
        end
    end

end

