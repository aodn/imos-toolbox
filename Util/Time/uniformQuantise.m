function [aq] = uniformQuantise(a, step)
% function [aq] = uniformQuantise(a,step)
%
% A wrapper to uniform quantisation of an array by a step.
%
% Inputs:
%
% a - an array
% step - a quantise step
%
% Outputs:
%
% aq - quantise array
%
% Example:
% %discard miliseconds
% msec = 0.001/86400; % ~1e-08
% y = uniformQuantise(msec, 1e-7);
% assert(y==0);
%
% author: hugo.oliveira@utas.edu.au
%

% Copyright (C) 2020, Australian Ocean Data Network (AODN) and Integrated
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
if step > 1
    error('Quantization step should be less than 1.')
end

aq = step .* floor(a ./ step + 0.5);

end
