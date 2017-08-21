% Test to exersize the function SBE19Parse 
% this function parses Sea-Bird DataProcessor generated files

%sample_data = SBE19Parse({'test\test04\sbe16example.cnv'}, 'timeseries');
%sample_data.meta.instrument_model


%% Test 1: parse SBE19 file
sd = SBE19Parse({'test\test04\Test 4550.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE19plus'), 'Failed: Parse SBE19 file')


%% Test 2: parse SBE9 file
sd = SBE19Parse({'test/test04/SBE9_example.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE 9'), 'Failed: Parse SBE9 file')

%% Test 3: parse SBE16plus file
sd = SBE19Parse({'test/test04/SBE16plus_example.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE16plus'), 'Failed: Parse SBE16 file')

%% Test 4: parse SBE25plus file
sd = SBE19Parse({'test/test04/SBE25plus_example.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE25plus'), 'Failed: Parse SBE25 file')

%% Test 5: parse SBE37 file
sd = SBE19Parse({'test/test04/SBE37_example.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE37SM-RS232'), 'Failed: Parse SBE37 file')

%% Test 6: parse SBE16plus file
sd = SBE19Parse({'test/test04/SBE39plus_example.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE39plus'), 'Failed: Parse SBE39 file')

%% Test 7: parse SBE37SMP-ODO file
sd = SBE19Parse({'test/test04/SBE37SMP-ODO-RS232_03709513_2016_04_03.cnv'}, 'timeseries');
assert(strcmp(sd.meta.instrument_model,'SBE37SMP-ODO-RS232'), 'Failed: Parse SBE37SMP-ODO-RS232 file')
