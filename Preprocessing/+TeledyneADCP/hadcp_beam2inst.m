function btim = hadcp_beam2inst(beam_angle)
%function btim = hadcp_beam2inst(beam_angle)
%
% Return the H-ADCP transformation matrix for conversion
% between beam coordinates to instrument coordinates.
%
% The beam_angle of RDI H-ADCPs are typically 30,25, or 20 degrees.
% while nearly all ADCPs are convex (only early vessel-mounted systems
% were concave).
%
% Reference: page 12 of ADCP Coordinate Transformation, 
% Formulas and Calculations, Teledyne RD Instruments.
% P/N 951-6079-00 (January 2008).

% Inputs:
%
% beam_angle [double] - beam angle in degrees.
% is_convex [logical] - boolean for convex adcp.
%                       Default: true
%
% Outputs:
%
% btim [double] - A 4x4 beam to instrument transformation matrix.
%
% % Example:
%
% % Compare Beam angle table values presented in the teledyne ADCP manual, page.12.
% expected = [-1,1,0,0; -0.34641,-0.34641, -0.4, 0; 0,0,0,0; 0.63246, 0.63246,-1.09545,0];
% decrange = 5;
% btim = TeledyneADCP.hadcp_beam2inst(30);
% assert(isequal_tol(expected,btim,decrange));
%
% author: hugo.oliveira@utas.edu.au
%
warnmsg('H-ADCP is not supported yet.')

p0 = 1 + 2 * cosd(beam_angle).^2;

a = 1 / (2 * sind(beam_angle));
c = 1 / p0;
b = cosd(beam_angle) * c;
e1 = a * sqrt(c);
e2 = 1 / (tand(beam_angle) * sqrt(p0));

btim = [-a, a, 0, 0; ...
        -b, -b, -c, 0; ...
        0, 0, 0, 0; ...
        e1, e1, -e2, 0; ...
        ];
end
