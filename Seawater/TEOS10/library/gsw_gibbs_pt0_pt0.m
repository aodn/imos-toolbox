function gibbs_pt0_pt0 = gsw_gibbs_pt0_pt0(SA,pt0)

% gsw_gibbs_pt0_pt0                                   gibbs_tt at (SA,pt,0)
%==========================================================================
% This function calculates the second derivative of the specific Gibbs 
% function with respect to temperature at zero sea pressure.  The inputs 
% are Absolute Salinity and potential temperature with reference sea 
% pressure of zero dbar.  This library function is called by both 
% "gsw_pt_from_CT(SA,CT)" ,"gsw_pt0_from_t(SA,t,p)" and
% "gsw_pt_from_entropy(SA,entropy)".
%
% VERSION NUMBER: 3.05 (27th January 2015)
%
%==========================================================================

% This line ensures that SA is non-negative.
SA(SA < 0) = 0;

sfac = 0.0248826675584615;                % sfac = 1/(40*(35.16504/35));

x2 = sfac.*SA;
x = sqrt(x2);
y = pt0.*0.025;

g03 = -24715.571866078 + ...
    y.*(4420.4472249096725 + ...
    y.*(-1778.231237203896 + ...
    y.*(1160.5182516851419 + ...
    y.*(-569.531539542516 + y.*128.13429152494615))));

g08 = x2.*(1760.062705994408 + x.*(-86.1329351956084 + ...
    x.*(-137.1145018408982 + y.*(296.20061691375236 + ...
    y.*(-205.67709290374563 + 49.9394019139016.*y))) + ...
    y.*(-60.136422517125 + y.*10.50720794170734)) + ...
    y.*(-1351.605895580406 + y.*(1097.1125373015109 +  ...
    y.*(-433.20648175062206 + 63.905091254154904.*y))));

gibbs_pt0_pt0 = (g03 + g08).*0.000625;

end
