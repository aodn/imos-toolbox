function entropy_part_zerop = gsw_entropy_part_zerop(SA,pt0)

% gsw_entropy_part_zerop          entropy_part evaluated at the sea surface
%==========================================================================
% This function calculates entropy at a sea pressure of zero, except that 
% it does not evaluate any terms that are functions of Absolute Salinity 
% alone.  By not calculating these terms, which are a function only of 
% Absolute Salinity, several unnecessary computations are avoided 
% (including saving the computation of a natural logarithm). These terms 
% are a necessary part of entropy, but are not needed when calculating 
% potential temperature from in-situ temperature.  
% The inputs to "gsw_entropy_part_zerop(SA,pt0)" are Absolute Salinity 
% and potential temperature with reference sea pressure of zero dbar.
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

g03 =  y.*(-24715.571866078 + y.*(2210.2236124548363 + ...
    y.*(-592.743745734632 + y.*(290.12956292128547 + ...
    y.*(-113.90630790850321 + y.*21.35571525415769)))));

g08 = x2.*(x.*( x.*(y.*(-137.1145018408982 + y.*(148.10030845687618 + ...
    y.*(-68.5590309679152 + 12.4848504784754.*y)))) + ...
    y.*(-86.1329351956084 + y.*(-30.0682112585625 + y.*3.50240264723578))) + ...
    y.*(1760.062705994408 + y.*(-675.802947790203 + ...
    y.*(365.7041791005036 + y.*(-108.30162043765552 + 12.78101825083098.*y)))));

entropy_part_zerop = -(g03 + g08).*0.025;

end
