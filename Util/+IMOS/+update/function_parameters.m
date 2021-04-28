function function_parameters(optname,optvalue)
% function function_parameters(optname,optvalue)
%
% Update the current function parameters
% This opens a txt file with the same name 
% as the running function, and
% update the respective option with the respective value.
%
% Inputs:
%
% optname - the name of the option.
% optvalue - the value of the option.
%
% Outputs:
%
%
% Example:
% %see usage in imosEchoIntensityQC.
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(2, 2)
called_by_function = callerName();
if isempty(called_by_function)
    return
end
fpath = which(called_by_function);
[folder, fname] = fileparts(fpath);
ofile_path = [fullfile(folder, fname) '.txt'];

missing_file = ~exist(ofile_path, 'file');
if missing_file
    errormsg('no parameter file for %s',fname);
end

updateMappings(ofile_path,optname,optvalue);
end
