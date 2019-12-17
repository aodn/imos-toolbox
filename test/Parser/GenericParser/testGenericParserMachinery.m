classdef testGenericParserMachinery < matlab.unittest.TestCase

    % Test GenericParser Machinery functions
    %
    % author: hugo.oliveira@utas.edu.au
    %
    properties (TestParameter)
        textfile = files2namestruct(rdir([toolboxRootPath 'data/testfiles/RBR'])); % All processed RBR files are text files ATM
        jfefile = files2namestruct(rdir([toolboxRootPath 'data/testfiles/JFE/v000/']));

    end

    methods (Test)

        function test_argstruct(~)
            cell_of_args = {1, 2, 3};
            afunc = @(x, y, z) (x + y + z);
            [astruct] = argstruct(cell_of_args, afunc);
            assert(isequal(astruct.args, cell_of_args),'input mapping to args is wrong')
            assert(isfunctionhandle(astruct.fun),'input mapping to fun is wrong')
            assert(astruct.fun(astruct.args{:}) == 6,'unexpected result of fun(args)')
        end

        function test_detectEconding(~, textfile)
            [encoding, mf] = detectEncoding(textfile);
            assert(strcmp(encoding, 'windows-1252'),'detection of encoding is wrong');
            assert(strcmp(mf, 'ieee-le.l64'),'detection of macineformat is wrong');
        end

        function test_mapDataNames(~)
            % simplest form
            sdata.procdata.date = [1, 2, 3];
            map_rules.date = @(x) 'TIME';
            [data] = mapDataNames(sdata.procdata, map_rules);
            assert(isequal(data.TIME, [1, 2, 3]));
            % with header info fields
            sdata.procdata.date = [1, 2, 3];
            sdata.procdata.variable_1 = [10, 20, 30];
            sdata.procdata.variable_2 = [-10, -20, -30];
            header_info = struct('columnname_1', 'DATE', 'columnname_2', 'TEMP', 'columnname_3', 'DEPTH');
            k = 1;
            map_rules.date = @(hinfo) (header_info.(['columnname_' num2str(k)]));
            k = 2;
            map_rules.variable_1 = @(hinfo) (header_info.(['columnname_' num2str(k)]));
            k = 3;
            map_rules.variable_2 = @(hinfo) (header_info.(['columnname_' num2str(k)]));
            [data] = mapDataNames(sdata.procdata, map_rules, header_info);
            assert(isequal(data.DATE, [1, 2, 3]),'could not map columnname_1 to DATE name');
            assert(isequal(data.TEMP, [10, 20, 30]),'could not map columnname_2 to TEMP name');
            assert(isequal(data.DEPTH, [-10, -20, -30]),'could not map columnname_3 to DEPTH name');
        end

        function test_readHeaderDict(~)
            cell_line_str = {'field: Velocity', 'units: m/s'};
            func = @regexpi;
            args = {'^(?<key>(.+?(?=:))):\s(?<value>(.+?))$', 'names'};
            [dicts] = readHeaderDict(cell_line_str, func, args);
            assert(isequal(dicts{1}, struct('key', 'field', 'value', 'Velocity')),'could not find velocity field');
            assert(isequal(dicts{2}, struct('key', 'units', 'value', 'm/s')),'could not find velocity units');
        end

        function test_readLinesWithRegex(~, jfefile)
            fid = fopen(jfefile, 'r');
            re_signature = '^((?!\[Item\]).+)$';
            [mlines] = readLinesWithRegex(fid, re_signature, true);
            assert(contains(lower(mlines{1}), 'infinity'),'no infinity instrument id in header');
            assert(~any(contains(mlines{end}, 'Item')),'metadata reading overflow into data block');
        end

        function test_translateHeaderText(~)
            header_kv = {struct('key','x','value','y')};
            rules.is_x_value_a_numeric = struct('args',{{'x'}},'fun',@isnumeric);
            [z] = translateHeaderText(header_kv,rules);
            assert(z.is_x_value_a_numeric==false,'translation by fun(header_kv.key) is wrong');
        end


    end

end
