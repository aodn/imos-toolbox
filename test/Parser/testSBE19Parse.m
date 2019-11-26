classdef testSBE19Parse < matlab.unittest.TestCase

    % Test Reading SBE files with the SBE19Parse
    % function.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        mode = {'timeSeries'};
        wqm_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE']));
    end

    methods (Test)

        function testReadInstrumentModel(~, wqm_file, mode)
            dict = load_table();
            data = SBE19Parse({wqm_file}, mode);
            [~, filename, ext] = fileparts(wqm_file);
            key = [filename ext];

            if dict.isKey(key)
                assert(strcmpi(data.meta.instrument_model, dict(key)));
            else
                warning('not validating instrumentmodel - file %s not registred in the table', key)
            end

        end

    end

end

function [table] = load_table()
% provide a table with filenames as keys
% and values as instrument models

table = containers.Map();
table('2015-05-09T094336_SBE02501008.cnv') = 'SBE25plus';
table('2015-05-09T114649_SBE02501008.cnv') = 'SBE25plus';
table('2015-05-09T191734_SBE02501008.cnv') = 'SBE25plus';
table('2015-05-09T213803_SBE02501008.cnv') = 'SBE25plus';
table('2015-05-15T022019_SBE02501008.cnv') = 'SBE25plus';
table('2016-11-29T063814_SBE0251111CFALDB.cnv') = 'SBE25plus';
table('chla_aquaT3_as_aquaUV.cnv') = 'SBE19plus';
table('IMOS_ANMN-NRS_CTP_130130_NRSMAI_FV00_CTDPRO.cnv') = 'SBE19plus';
table('IMOS_ANMN-NRS_CTP_130130_NRSMAI_FV00_CTDPRO.cnv') = 'SBE19plus';
table('in2015_c01_005CFALDB_altimetre.cnv') = 'SBE9';
table('SBE16plus_oxygen1.cnv') = 'SBE16plus';
table('SBE16plus_oxygen2.cnv') = 'SBE16plus';
table('SBE16plus_oxygen3.cnv') = 'SBE16plus';
table('SBE16plus_parser1.cnv') = 'SBE16plus';
table('SBE16plus_parser1.cnv') = 'SBE16plus';
table('SBE16plus_parser2.cnv') = 'SBE16plus';
table('SBE16plus_parser2.cnv') = 'SBE16plus';
table('SBE19plus_parser1.cnv') = 'SBE19plus';
table('SBE25plus_parser1.cnv') = 'SBE25plus';
table('SBE37_parser1.cnv') = 'SBE37SM-RS232';
table('SBE37_parser1.cnv') = 'SBE37SM-RS232';
table('SBE39plus_parser1.cnv') = 'SBE39plus';
table('SBE9_parser1.cnv') = 'SBE9';
end
