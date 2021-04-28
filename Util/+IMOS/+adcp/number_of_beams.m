function [number_of_beams] = number_of_beams(sample_data)
% function [n] = number_of_beams(sample_data)
%
% Detect the number of beams in a toolbox
% struct.
%
% Inputs:
%
% sample_data [struct] - the toolbox struct.
%
% Outputs:
%
% number_of_beams [numeric] - ditto.
%
% Example:
%
% %basic usage
% s.meta.adcp_info.number_of_beams = 4;
% assert(IMOS.adcp.number_of_beams(s)==4);
% x.meta.nBeams = 3;
% assert(IMOS.adcp.number_of_beams(x)==3);
% y.variables = {struct('name','WCUR_2')};
% assert(IMOS.adcp.number_of_beams(y)==4);
% z.variables = {struct('name','ECUR')};
% assert(IMOS.adcp.number_of_beams(y)==4);
% q.variables = {struct('name','WCUR')};
% assert(IMOS.adcp.number_of_beams(q)==3);
% q = struct();
% assert(IMOS.adcp.number_of_beams(q)==0);
%
%
% author: hugo.oliveira@utas.edu.au
%
try
    number_of_beams = sample_data.meta.adcp_info.number_of_beams;
catch

    try
        number_of_beams = sample_data.meta.nBeams;
    catch

        try
            vars = IMOS.get(sample_data.variables, 'name');

            if inCell(vars, 'WCUR_2') || inCell(vars, 'ECUR')
                number_of_beams = 4;
            else
                number_of_beams = 3;
            end

        catch
            number_of_beams = 0;
        end

    end

end
