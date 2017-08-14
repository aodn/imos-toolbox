% Test to exersize the function oxygenPP

% function sample_data = oxygenPP( sample_data, qcLevel, auto )

sample_data            = struct;
sample_data.meta       = struct;
sample_data.variables  = {};
sample_data.dimensions = {};
sample_data.history    = [];

sample_data.toolbox_input_file          = 'test02.m';
% sample_data.geospatial_lat_min          = -46;
% sample_data.geospatial_long_min         = 142;

time = [ datenum(2017,1,1) datenum(2017,1,2) datenum(2017,1,3) datenum(2017,1,4) ];
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(time);

temp = [ 12.2532  12.2295     14.996401  14.996401 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'TEMP';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(temp);

pres_rel = [ 29.666  6330.549  100.0  3000.0 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PRES_REL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(pres_rel);

psal = [  34.9083   32.8283  35.0  35.0 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PSAL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(psal);

dox = [  5.6252  13.6856  5.6252  5.6252 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'DOX';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(dox);

sam{1} = sample_data;

sam = oxygenPP(sam, 'qc');

oxsol = sam{1}.variables{getVar(sam{1}.variables, 'OXSOL')}.data;
dox2 = sam{1}.variables{getVar(sam{1}.variables, 'DOX2')}.data;
doxs = sam{1}.variables{getVar(sam{1}.variables, 'DOXS')}.data;

%% Test 1: Oxygen Solubility
assert(sum(abs(oxsol - [262.05291   271.6910     247.8694    250.209])   > 1e-2) == 0, 'Failed: Oxygen Solubility Check')

%% Test 2: DOX2
assert(sum(abs(dox2 -  [244.745     596.267      244.8609    244.8362])  > 1e-2) == 0, 'Failed: DOX2 Check')

%% Test 2: DOXS
assert(sum(abs(doxs -  [0.93395     2.1946267    0.9878625   0.9785269])  > 1e-4) == 0, 'Failed: DOXS Check')

%% test 3: DOX2 from DOX1

clear sample_data
sample_data            = struct;
sample_data.meta       = struct;
sample_data.variables  = {};
sample_data.dimensions = {};
sample_data.history    = [];

sample_data.toolbox_input_file          = 'test02.m';

time = [ datenum(2017,1,1) ];
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(time);

temp = [ 12.2532  ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'TEMP';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(temp);

pres_rel = [ 29.666 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PRES_REL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(pres_rel);

psal = [  35.0 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PSAL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(psal);

dox = [  5.6252 * 44.6596 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'DOX1';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(dox);

sam{1} = sample_data;

sam = oxygenPP(sam, 'qc');

oxsol = sam{1}.variables{getVar(sam{1}.variables, 'OXSOL_SURFACE')}.data;
dox2 = sam{1}.variables{getVar(sam{1}.variables, 'DOX2')}.data;
doxs = sam{1}.variables{getVar(sam{1}.variables, 'DOXS')}.data;

assert(sum(abs(dox2 -  [244.7239])  > 1e-2) == 0, 'Failed: DOX2 Check')

%% test 4: DOX2 from DOXS

clear sample_data
sample_data            = struct;
sample_data.meta       = struct;
sample_data.variables  = {};
sample_data.dimensions = {};
sample_data.history    = [];

sample_data.toolbox_input_file          = 'test02.m';

time = [ datenum(2017,1,1) ];
sample_data.dimensions{1}.name          = 'TIME';
sample_data.dimensions{1}.typeCastFunc  = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{1}.name, 'type')));
sample_data.dimensions{1}.data          = sample_data.dimensions{1}.typeCastFunc(time);

temp = [ 12.2532  ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'TEMP';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(temp);

pres_rel = [ 29.666 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PRES_REL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(pres_rel);

psal = [  35.0 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'PSAL';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(psal);

dox = [ 0.9 ];
sample_data.variables{end+1}.dimensions = 1;
sample_data.variables{end}.name         = 'DOXS';
sample_data.variables{end}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(sample_data.dimensions{end}.name, 'type')));
sample_data.variables{end}.data = sample_data.variables{end}.typeCastFunc(dox);

sam{1} = sample_data;

sam = oxygenPP(sam, 'qc');

oxsol = sam{1}.variables{getVar(sam{1}.variables, 'OXSOL_SURFACE')}.data;
dox2 = sam{1}.variables{getVar(sam{1}.variables, 'DOX2')}.data;
doxs = sam{1}.variables{getVar(sam{1}.variables, 'DOXS')}.data;

assert(sum(abs(dox2 -  [235.6999])  > 1e-2) == 0, 'Failed: DOX2 Check')

