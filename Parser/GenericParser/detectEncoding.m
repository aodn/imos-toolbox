function [encoding, machineformat] = detectEncoding(filename)
%function [encoding, machineformat] = detectEncoding(filename)
%
% A function to load/detect the Encoding of a file.
% The detection is dynamic, but unfortunately can be slow since
% we need to load the entire file several times.
%
% Inputs:
%
% filename - a string with the filename path.
%
% Outputs:
%
% encoding - an encoding string
% machineformat - the machineformat string
%
% Example:
% % automatic detection
% filename = [toolboxRootPath() 'data/testfiles/RBR/duet3/v000/082533_20190525_0515_eng_rbrduet3.txt']
% encoding = detectEncoding(filename);
% assert(strcmp(encoding,'windows-1252'));
%
% author: hugo.oliveira@utas.edu.au
%

mflist = machineformat_list();
mclist = encoding_list();

badstring_list = {'�'};

for m = 1:length(mflist)

    for n = 1:length(mclist)
        machineformat = mflist{m};
        encoding = mclist{n};
        [fid, ferr] = fopen(filename, 'r', machineformat, encoding);

        if fid < 0
            error([ferr ': %s'], filename)
        end

        wstr = fscanf(fid, '%s');

        for s = 1:length(badstring_list)
            badstring = badstring_list{s};

            if ~contains(wstr, badstring)
                fclose(fid);
                return
            end

        end

    end

end

fclose(fid);
error('Couldn''t detect machineformat/encoding for file %s', filename);

end

function [mclist, others] = encoding_list()
%function encoding_list()
%
% Provide two cell of strings containing
% the most used encodings and the less used
% encodings.
%
% Outputs:
%
% mclist - cell of strings - the most common list of encodings
% others - cell of strings - the less common list of encodings
%
% Example:
%
% [mclist] = encoding_list();
% assert(inCell(mclist,'windows-1252'));
% assert(inCell(mclist,'US-ASCII'));
% assert(inCell(mclist,'UTF-8'));
% assert(inCell(mclist,''))
%

mclist = {'windows-1252', 'ISO-8859-1', 'US-ASCII', 'UTF-8'};

others = {
'windows-874', ...
    'windows-949', ...
    'windows-1250', ...
    'windows-1251', ...
    'windows-1253', ...
    'windows-1254', ...
    'windows-1255', ...
    'windows-1256', ...
    'windows-1257', ...
    'windows-1258', ...
    'ISO-8859-2', ...
    'ISO-8859-3', ...
    'ISO-8859-4', ...
    'ISO-8859-5', ...
    'ISO-8859-6', ...
    'ISO-8859-9', ...
    'ISO-8859-7', ...
    'ISO-8859-8', ...
    'ISO-8859-11', ...
    'ISO-8859-13', ...
    'ISO-8859-15', ...
    'Macintosh', ...
    'Big5-HKSCS', ...
    'Big5', ...
    'CP949', ...
    'EUC-KR', ...
    'EUC-JP', ...
    'EUC-TW', ...
    'GB18030', ...
    'GB2312', ...
    'GBK', ...
    'IBM866', ...
    'KOI8-R', ...
    'KOI8-U', ...
    'Shift_JIS'
};
end

function [mflist] = machineformat_list()
% function mflist = machineformat_list()
%
% Load all machine formats available
%
% Outputs:
%
% mflist - a cell with all machine formats supported.
%
% Example:
% mflist = machineformat_list();
% assert(inCell(mflist,'iee-le.l64'));
% assert(inCell(mflist,'ieee-be.l64'));
%
% author: hugo.oliveira@utas.edu.au
%
mflist = {'ieee-le.l64', 'ieee-le', 'ieee-le.l64', 'ieee-be'};
end
