function sample_data_averaged=imosRDIbinAveragingCSIRO(sample_data,binInt)
% Uses a moving average to smooth the data, then interpolates to new time
% grid
% Required inputs:
%	sample_data: structure of data for all instruments
%   binInt : desired avg interval in seconds
% Outputs:
%	sample_data_averaged: structure with averaged data
% Rebecca Cowley, June 2020
%% Improvements & Limitations
%		Not all datafields will be supported, it's a work in progress
% 		Could output a structure with all the structures, but given the shear volume of data, I prefer saving as we go so that I can restart a given Navg
%	Should remove fields not used in adcp, to make it smaller/faster fpr the code to handle

%set a default bin average of 60 minutes (3600seconds)
if nargin==1, binInt = 3600; end

%get our new structure ready:
sample_data_averaged = sample_data;

for k = 1:length(sample_data)
    % do not process if not RDI nor Nortek
    isRDI = false;
    if strfind(sample_data.name, 'RDI'), isRDI = true; end
    if ~isRDI, continue; end 

    %set up the time range
    time = sample_data.time;
    sampInt = sample_data.time_int; % mean samping interval in seconds
    N = binInt/sampInt;
    new_datestamp = time(1)+(N*sampInt/2)/(3600*24):binInt/(3600*24):time(end); % the datestmp mid-way through the interval, str date
    
    %PRESSURE-averaging.  If pressure recorded every ping, it
    %is noisy, this needs to be cleaned up first
    sample_data.depth = g_boxcar_smoothNONAN(sample_data.depth',N)';
    %recalculate the bdepth:
    sample_data.bdepth = repmat(sample_data.depth,1,length(sample_data.brange)) ...
        - repmat(sample_data.brange',length(sample_data.depth),1);

    %start bin averaging
    isBinAverageApplied = false;
    % now we operate on anything with TIME as a dimension.
    fldnms = fieldnames(sample_data);
    for j=1:length(fldnms)
        if ~isempty(strfind(fldnms{j},'_qc')), continue, end
        if ~isempty(strfind(fldnms{j},'time')), continue, end
        if any(size(sample_data.(fldnms{j})) == length(time))
            isBinAverageApplied = true;
            % bin average the data:
            if binInt<sampInt
                warning('You''ve specified an averaging period smaller than sampling interval, aborted.');
                continue
            end
            %remove flagged data before continuing:
            singlePing = sample_data.(fldnms{j});
            try
                flags = sample_data.([fldnms{j} '_qc']);
            catch
                flags = zeros(size(singlePing));
            end
            if isreal(singlePing)
                singlePing(flags > 2) = NaN;
            else
                singlePing(flags > 2) = NaN + NaN*i;
            end
           
            inan = isnan(singlePing);
            if ~isreal(singlePing)
                avDat1 = g_boxcar_smoothNONAN(imag(singlePing)',N)';
                avDat2 = g_boxcar_smoothNONAN(real(singlePing)',N)';
                avDat = complex(avDat2,avDat1);
            else
                avDat = g_boxcar_smoothNONAN(singlePing',N)';
            end
            if isreal(avDat)
                avDat(inan) = NaN;
            else
                avDat(inan) = NaN + NaN*i;
            end
            
            %now interpolate
            averagedData = interp1(time,avDat,new_datestamp');
            if isBinAverageApplied
                % we re-assign the data                
                sample_data_averaged.(fldnms{j}) = averagedData;
                
                
                %also need to re-make the flags HOW TO KEEP THE OUT OF WATER
                %FLAGS? OR, DO WE JUST HAVE AN AVERAGED PRODUCT WITH ONLY GOOD,
                %IN-WATER DATA? ALL FLAGS WOULD THEN BE 1.
                sample_data_averaged.([fldnms{j} '_qc']) = ones(size(averagedData));
            end
        end
    end
    if isBinAverageApplied
        sample_data_averaged.time = new_datestamp';
        sample_data_averaged.time_in = new_datestamp(1);
        sample_data_averaged.time_out = new_datestamp(end);
        
    end
end


