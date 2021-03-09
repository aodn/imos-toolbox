function [time] = convert_time(variable, instrument_firmware)
%
% Compute time variable based on the ADCP firmware version.
%
% Inputs:
%
% variable[struct] - the variable substruct obtained from
%                    readWorkhorseEnsembles.m
% instrument_firmware[str] - the firmware version string.
%
% Outputs:
%
% time[double] - the datenum time.
%
% Example:
%
% vs.y2kCentury=20;
% vs.y2kYear=1;
% vs.y2kMonth=2;
% vs.y2kDay=3;
% vs.y2kHour=4;
% vs.y2kMinute=56;
% vs.y2kSecond=12;
% vs.y2kHundredth=.5;
% firmware = '50';
% time = Workhorse.convert_time(vs,firmware);
% assert(strcmpi('2001-02-03T04:56:12.005',datestr(time,'yyyy-mm-ddTHH:MM:SS.FFF')));
%

narginchk(2, 2)

if str2double(instrument_firmware) > 8.35
    time = datenum(...
        [variable.y2kCentury * 100 + variable.y2kYear, ...
            variable.y2kMonth, ...
            variable.y2kDay, ...
            variable.y2kHour, ...
            variable.y2kMinute, ...
            variable.y2kSecond + variable.y2kHundredth / 100.0]);
else
    % looks like before firmware 8.35 included, Y2K compliant RTC time
    % was not implemented
    century = 2000;

    if variable.rtcYear(1) > 70
        % first ADCP was built in the mid 1970s
        % hopefully this firmware will no longer be used
        % in 2070...
        century = 1900;
    end

    time = datenum(...
        [century + variable.rtcYear, ...
            variable.rtcMonth, ...
            variable.rtcDay, ...
            variable.rtcHour, ...
            variable.rtcMinute, ...
            variable.rtcSecond + variable.rtcHundredths / 100.0]);
end

end
