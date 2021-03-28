function btim = workhorse_beam2inst(beam_angle, beam_pattern)
%function btim = workhorse_beam2inst(beam_angle, beam_pattern)
%
% Return the default Workhorse transformation matrix
% between beam coordinates to instrument coordinates.
%
% The beam_angle of RDI workhorse ADCPs are typically
% either 20 or 30 degrees, while nearly all ADCPs
% are convex (only early vessel-mounted systems were concave).
%
% Note: This matrix assumes the ADCP was NOT 
% corrected for being misalignment (default matrix).
% 
% Reference: page 11 of ADCP Coordinate Transformation,
% Formulas and Calculations, Teledyne RD Instruments.
% P/N 951-6079-00 (January 2008).
%
%
% Inputs:
%
% beam_angle [double] - beam angle in degrees.
% beam_pattern [str] - the beam_pattern ['convex' | 'concave']
%                      Default: 'convex'
%
% Outputs:
%
% btim [double] - A 4x4 beam to instrument transformation matrix.
%
% % Example:
%
% % Compare a,b,d values presented in the teledyne ADCP manual, page 11.
% expected = [1,-1,0,0; 0,0,-1, 1;0.2887,0.2887,0.2887,0.2887;0.7071,0.7071,-0.7071,-0.7071]
% decrange = 4;
% btim = TeledyneADCP.workhorse_beam2inst(30);
% assert(isequal_tol(expected,btim,decrange));
%
% author:  hugo.oliveira@utas.edu.au
%
%
narginchk(1, 2)

if nargin > 1
    if strcmpi(beam_pattern, 'convex')
        c = 1;
    elseif strcmpi(beam_pattern, 'concave')
        c = -1;
    else
        errormsg('Invalid beam_pattern argument')
    end
else
    c = 1; % convex
end


    % Create the apropriate scale factors:
    %
    a = 1 / (2 * sind(beam_angle));
    b = 1 / (4 * cosd(beam_angle));

    d = a / sqrt(2);

    btim = [c * a, -c * a, 0, 0; ...
            0, 0, -c * a, c * a; ...
            b, b, b, b; ...
            d, d, -d, -d; ...
            ];
end
