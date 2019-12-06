function [chla_str] = getCPHLcomment(modestr, excitation_wl_str, scattered_wl_str)
    % function chla_str = getCPHLcomment(modestr,led_wl_str, excitation_wl_str, scattered_wl_str)
    %
    % Generate a big comment for a chlorophyll sensor
    %
    % Inputs:
    %
    % modestr - The chla coef. mode string ['user','factory','unknown']
    % excitation_wl_str - The LED excitation wavelength string ['470nm','430nm']
    % scattered_wl_str - The scattered wavelength (centre/region) ['685nm','695nm','650nm to 1000nm','above 630nm']
    %
    % Outputs:
    %
    % chla_str - A big string regarding the chla attribute
    %
    % Example:
    % >>> [chla_str] = getCPHLcomment('factory','470nm','695nm');
    % >>> assert(contains(chla_str,'factory calibration coefficient'));
    % >>> assert(contains(chla_str,'470nm peak wavelength'));
    % >>> assert(contains(chla_str,'fluoresces in the region of 695nm'));
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

    if ~contains({'user', 'factory', 'unknown'}, modestr)
        error('CPHL coefficient id is invalid')
    end

    if contains({' to '}, excitation_wl_str)
        e_conn = 'from';
    elseif contains({'above'}, excitation_wl_str)
        e_conn = '';
    else
        e_conn = 'of';
    end

    %TODO this should be build on a table for each instrument...
    chla_str = ['Artificial chlorophyll data ' ...
                'computed from bio-optical sensor raw counts measurements. The ' ...
                'fluorometre is equipped with a ' excitation_wl_str ' peak wavelength ' ...
                'LED to irradiate and a photodetector paired with an optical filter ' ...
                'which measures everything that fluoresces in the region ' ...
                e_conn ' ' scattered_wl_str '. ' ...
                'Originally expressed in ug/l, 1l = 0.001m3 was assumed.'];
end
