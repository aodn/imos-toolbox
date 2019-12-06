function nowt = now_utc()
%NOW_UTC return the current time in UTC

msUTC = java.lang.System.currentTimeMillis(); % returns the difference, measured in milliseconds, between the current time and midnight, January 1, 1970 UTC
nowt = msUTC / 86400000 + datenum([1970 1 1]); % number of days in UTC
