classdef testSignature < matlab.unittest.TestCase

    % Test Reading Nortek Signature files with the SignatureParser
    % function.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        mode = {'timeSeries'};
        s250_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/signature_250/v000']));
        s500_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/signature_500/v000']));
        s1000_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Nortek/signature_1000/v000']));

    end

    methods (Test)

        function testReadSignature250(~, s250_file, mode)
            data = signatureParse({s250_file},mode);
            assert(strcmp(data{1}.meta.instrument_model,'Signature250'));
            assert(strcmp(data{1}.meta.instrument_make,'Nortek'));
            assert(data{1}.meta.beam_angle==20);
        end

        function testReadSignature500(~, s500_file, mode)
            data = signatureParse({s500_file},mode);
            assert(strcmp(data{1}.meta.instrument_model,'Signature500'));
            assert(strcmp(data{1}.meta.instrument_make,'Nortek'));
            assert(data{1}.meta.beam_angle==25);
        end

        function testReadSignature1000(~, s1000_file, mode)
            data = signatureParse({s1000_file},mode);
            assert(strcmp(data{1}.meta.instrument_model,'Signature1000'));
            assert(strcmp(data{1}.meta.instrument_make,'Nortek'));
            assert(data{1}.meta.beam_angle==25);
        end


    end

end

