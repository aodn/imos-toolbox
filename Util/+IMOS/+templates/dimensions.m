classdef  dimensions
	% A collection of minimal IMOS dimensions templates.
	properties (Constant)
		timeseries = timeseries_dims();
		profile = profile_dims();
		ad_profile = ad_profile_dims();
		adcp = adcp_dims();
		adcp_enu = adcp_enu_dims();
	end
end

function [dimensions] = timeseries_dims()
%create basic timeseries dimensions
dimensions = {struct('name','TIME','typeCastFunc',getIMOSType('TIME'),'data',[],'comment','')};
end

function [dimensions] = profile_dims()
%create basic profile dimensions
dimensions = {struct('name','DEPTH','typeCastFunc',getIMOSType('DEPTH'),'data',[],'comment','','axis','Z')};
end

function [dimensions] = ad_profile_dims()
%create basic ad profile dimensions
dimensions = cell(1,2);
dimensions{1} = struct('name','MAXZ','typeCastFunc',getIMOSType('MAXZ'),'data',[]);
dimensions{2} = struct('name','PROFILE','typeCastFunc',getIMOSType('PROFILE'),'data',[]);
dimensions{2}.data = dimensions{2}.typeCastFunc([1,2]);
end

function [dimensions] = adcp_dims()
dimensions = timeseries_dims();
dimensions{2} = struct('name','DIST_ALONG_BEAMS','typeCastFunc',getIMOSType('DIST_ALONG_BEAMS'),'data',[]);
end

function [dimensions] = adcp_enu_dims()
dimensions = timeseries_dims();
dimensions{2} = struct('name','HEIGHT_ABOVE_SENSOR','typeCastFunc',getIMOSType('HEIGHT_ABOVE_SENSOR'),'data',[]);
end
