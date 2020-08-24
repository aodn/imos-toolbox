function [dataLines, instHeaderLines, procHeaderLines] = readSBEcnv(filename, ~)
%function [dataLines, instHeaderLines, procHeaderLines] = readSBEcnv(filename, ~)
%
% readSBEcnv Reads standard Seabird .cnv file and extract out data lines,
% instrument header lines and processed header lines.
%
% Inputs:
%   filename    - cell array of files to import (only one supported).
%   mode        - Toolbox data type mode.
%
%   dataLines  - Cell array of data lines in the original file.
%   instHeader - Cell array of instrument header lines.
%   procHeader - Cell array of processed header lines.
%   mode       - Toolbox data type mode.
%
% Outputs:
%   dataLines  - cell array of data lines.
%   instHeaderLines - cell array of instrument header lines.
%   procHeaderLines - cell array of processed header lines.

%
% Author: 		Simon Spagnol <s.spagnol@aims.gov.au>

% read in every line in the file, separating
% them out into each of the three sections

instHeaderLines = {};
procHeaderLines = {};
dataLines = {};

try

    fid = fopen(filename, 'rt');
    allLines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    allLines = allLines{1};
    iStar = strncmp(allLines, '*', 1);
    instHeaderLines = allLines(iStar);
    iHash = strncmp(allLines, '#', 1);
    procHeaderLines = allLines(iHash);
    % make assumption that everything else are data lines
    iData = ~(iStar | iHash);
    dataLines = allLines(iData);

catch e
    if fid ~= -1, fclose(fid); end
    rethrow(e);
end

end
