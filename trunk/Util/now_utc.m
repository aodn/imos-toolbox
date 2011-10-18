function nowt = now_utc()
%NOW_UTC return the current time in UTC

date = java.util.Date();
timezone = date.getTimezoneOffset() / 60 / 24;
nowt = now + timezone;
