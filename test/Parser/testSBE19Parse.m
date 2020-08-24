classdef testSBE19Parse < matlab.unittest.TestCase

    % Test Reading SBE files with the SBE19Parse
    % function.
    %
    % author: hugo.oliveira@utas.edu.au
    %

    properties (TestParameter)
        mode = {'timeSeries'};
        wqm_file = files2namestruct(rdir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE']));
        beam_transmission_file = prepend_dir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/19plus/v000'], {'YON20200306CFALDB_with_PAR_and_battery.cnv'});
        strain_pres_file = prepend_dir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/19plus/v000'], {'SBE19plus_parser1.cnv', 'YON20200306CFALDB_with_PAR_and_battery.cnv', 'chla_aquaT3_as_aquaUV.cnv'});
        par_file = prepend_dir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/19plus/v000'], {'SBE19plus_parser1.cnv', 'YON20200306CFALDB_with_PAR_and_battery.cnv', 'chla_aquaT3_as_aquaUV.cnv'});
        sbe_37sm_file = prepend_dir([toolboxRootPath 'data/testfiles/Sea_Bird_Scientific/SBE/37plus/v000'], {'SBE37_parser1.cnv'});

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

        function test_read_strain_pressure(~, strain_pres_file, mode)
            data = SBE19Parse({strain_pres_file}, mode);
            cols = data.meta.procHeader.columns;
            assert(inCell(cols, 'pr') || inCell(cols, 'prM') || inCell(cols, 'prdM') || inCell(cols, 'prDM') || inCell(cols, 'prSM'))
            assert(getVar(data.variables, 'PRES_REL') > 0)

        end

        function test_read_beam_transmission(~, beam_transmission_file, mode)
            data = SBE19Parse({beam_transmission_file}, mode);
            cols = data.meta.procHeader.columns;
            assert(inCell(cols, 'CStarTr0'))
            assert(getVar(data.variables, 'BAT_PERCENT') > 0)% this name should change.
        end

        function test_read_par(~, par_file, mode)
            data = SBE19Parse({par_file}, mode);
            cols = data.meta.procHeader.columns;
            assert(inCell(cols, 'par/log') || inCell(cols, 'par') || inCell(cols, 'par/sat/log'))
            assert(getVar(data.variables, 'PAR') > 0)

        end

        function test_basic_read(~, wqm_file, mode)
            data = SBE19Parse({wqm_file}, mode);
            cols = data.meta.procHeader.columns;
            assert(inCell(cols, 'pr') || inCell(cols, 'prM') || inCell(cols, 'prdM') || inCell(cols, 'prDM') || inCell(cols, 'prSM') || inCell(cols, 'depSM'))
            assert(getVar(data.variables, 'PRES_REL') > 0 || getVar(data.variables, 'PRES') > 0 || getVar(data.variables, 'DEPTH') > 0)
            assert(getVar(data.variables, 'TEMP') > 0)

            if ~contains(wqm_file, 'SBE39plus_parser1')%only file missing salinity
                assert(getVar(data.variables, 'CNDC') > 0 || getVar(data.variables, 'PSAL'))
            end

        end

    end

end

function ycell = prepend_dir(xdir, xcell)
%prepend a path xdir to all items in xcell.
n = length(xcell);
ycell = cell(1, n);

if xdir(end) ~= filesep
    xdir(end + 1) = filesep;
end

for k = 1:n
    ycell{k} = [xdir xcell{k}];
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
table('YON20200306CFALDB_with_PAR_and_battery.cnv') = 'SBE19plus';
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
