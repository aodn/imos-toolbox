function sample_data_averaged=imosRDIbinAveraging(sample_data,qcLevel,binInt)
% Averages data stored in the adcp structure array as requested in the cell array datafield.
%   The data are placed in a structure variables (e.g. adcp1min)
%	 and saved into a mat file called "avgvel.mat" (provided it doesnt already exixts, it will append a number otherwise)
% Required inputs:
%	adcp: structure of data as returned by ADCP code, with a mtime variable and preferably the z (height) variable for bottom -mounted/moored adcp
%	datafield: cell array of variables to process (e.g. 'enu','beam','hpr', 'corr','pressure',etc)
%   Navg:vector desired avg interval in seconds
% Outputs:
%	adcpBinned structure with averaged data
% Optional:
%   timlim=[stim etim] the start and end time of data to average if you
%   	want to remove the out of water in the datenum format
%   	stim=datenum(2012,4,4,12,0,0);
%  		 etim=datenum(2012,4,22,6,55,0);
%   Navg=[60 120 300 600]; % 1, 2, 5 and 10 min
% Based on code created by CBluteau in May 2015
% Rebecca Cowley, May 2020
%% Improvements & Limitations
%		Not all datafields will be supported, it's a work in progress
% 		Could output a structure with all the structures, but given the shear volume of data, I prefer saving as we go so that I can restart a given Navg
%	Should remove fields not used in adcp, to make it smaller/faster fpr the code to handle

narginchk(2, 3);
if isstruct(sample_data), error('sample_data must be a cell'); end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

%set a default bin average of 60 minutes (3600seconds)
if nargin==2, binInt = 3600; end

%get our new structure ready:
sample_data_averaged = sample_data;

for k = 1:length(sample_data)
    % do not process if not RDI nor Nortek
    isRDI = false;
    if strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), isRDI = true; end
    if ~isRDI, continue; end
    
    % get all necessary dimensions and variables id in sample_data struct
    idTime = getVar(sample_data{k}.dimensions, 'TIME');
    if idTime == 0
        disp('No Time dimesion, RDI bin averaging aborted')
        return
    end
    %set up the time range
    time = sample_data{k}.dimensions{idTime}.data;
    sampInt = sample_data{k}.instrument_average_interval; % mean samping interval in seconds
    N = binInt/sampInt;
    new_datestamp = time(1)+(N*sampInt/2)/(3600*24):binInt/(3600*24):time(end); % the datestmp mid-way through the interval, str date
    
    isBinAverageApplied = false;
    % now we operate on anything with TIME as a dimension.
    for j=1:length(sample_data{k}.variables)
        if any(sample_data{k}.variables{j}.dimensions == idTime)
            isBinAverageApplied = true;
            % bin average the data:
            if binInt<sampInt
                warning('You''ve specified an averaging period smaller than sampling interval, aborted.');
                continue
            end
            %remove flagged data before continuing:
            flags = sample_data{k}.variables{j}.flags;
            singlePing = sample_data{k}.variables{j}.data;
            singlePing(flags > 2) = NaN;
            
            [recordlength, m] = size(singlePing);
            singlePingCount = 1;
            averagedDataCount = 1;
            averagedData = zeros(length(new_datestamp),m);
            while singlePingCount<=recordlength
                lendat=singlePingCount+N-1; % or N*rowc
                data = singlePing(singlePingCount:lendat,:); % the data trying to retreive(wind,temp,etc)
                averagedData(averagedDataCount,:)=nanmean(data); % the interval mean
                    %TTEST code. Very slow. But, we should consider
                    %something to get an estimated uncertainty value out.
%                 for jj=1:m
%                     [ht,p,ci(averagedDataCount,jj,1:2)] =ttest(data(:,jj));
%                 end
                
                singlePingCount=singlePingCount+N;
                averagedDataCount=averagedDataCount+1;
                if singlePingCount+N>recordlength 	% dealing with the end of the record, basically doing as above
                    lendat=recordlength-singlePingCount+1;
                    data = data(singlePingCount:end,:); % the data trying to retreive(wind,temp,etc)
                    averagedData(averagedDataCount,:)=nanmean(data); % the interval mean
                    
                    %TTEST code. Very slow. But, we should consider
                    %something to get an estimated uncertainty value out.
%                     for jj=1:m
%                         [ht,p,ci(averagedDataCount,jj,1:2)] =ttest(data(:,jj));
%                     end
                    break
                end
            end
            if isBinAverageApplied
                RDIbinAveragingComment = ['RDIbinAveraging.m: data in single ping mode with a ' num2str(sampInt) ...
                    ' second sampling interval has been time-averaged to a ' num2str(binInt) ...
                    ' second interval using a boxcar averaging method'];
                % we re-assign the data                
                sample_data_averaged{k}.variables{j}.data = single(averagedData);
                
                comment = sample_data_averaged{k}.variables{j}.comment;
                if isempty(comment)
                    sample_data_averaged{k}.variables{j}.comment = RDIbinAveragingComment;
                else
                    sample_data_averaged{k}.variables{j}.comment = [comment ' ' RDIbinAveragingComment];
                end
                
                %also need to re-make the flags HOW TO KEEP THE OUT OF WATER
                %FLAGS? OR, DO WE JUST HAVE AN AVERAGED PRODUCT WITH ONLY GOOD,
                %IN-WATER DATA? ALL FLAGS WOULD THEN BE 1.
                sample_data_averaged{k}.variables{j}.flags = int8(ones(size(sample_data_averaged{k}.variables{j}.data)));
            end
        end
    end
    if isBinAverageApplied
        sample_data_averaged{k}.dimensions{idTime}.data = single(new_datestamp');
        sample_data_averaged{k}.dimensions{idTime}.flags = int8(zeros(size(new_datestamp')));
        %the time comment needs changing too... IMOS can fix this?
        history = sample_data_averaged{k}.history;
        if isempty(history)
            sample_data_averaged{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), RDIbinAveragingComment);
        else
            sample_data_averaged{k}.history = sprintf('%s\n%s - %s', history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), RDIbinAveragingComment);
        end
        sample_data_averaged{k}.time_coverage_start = new_datestamp(1);
        sample_data_averaged{k}.time_coverage_end = new_datestamp(end);
        
    end
end


