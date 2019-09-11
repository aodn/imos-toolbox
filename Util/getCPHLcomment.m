function [chla_str] = getCPHLcomment(modestr),
    % function chla_str = getCPHLcomment(modestr)
    %
    % Generate a big comment for chlorophyll sensor
    %
    % Inputs:
    %
    % modestr - The chla coef. mode string ['user','factory','unknown']
    %
    % Outputs:
    %
    % chla_strt - A big string regarding the chla attribute
    %
    % Example:
    % >>> modestr = 'factory'
    % >>> [chla_str] = getCPHLcomment(modestr)
    % >>> assert(contains(chla_str,'factory calibration coefficient'))
    %
    % author: hugo.oliveira@utas.edu.au
    %

    % Copyright (C) 2019, Australian Ocean Data Network (AODN) and Integrated
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

    if ~contains({'user', 'factory', 'unknown'}, modestr),
        error('CPHL coefficient id is invalid')
    end

    chla_str = ['conversion from fluorescence to chlorophyll-a using ' modestr ' coefficients.']
end
