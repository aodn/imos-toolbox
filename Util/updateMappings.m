function updateMappings(fname, name, value)
% function updateMappings(fname, name, value)
%
% This updates a mapping/Property in a mapping file,
% preserving the previous state of the file,
% including comments.
%
% A mapping/property file is a text file with the 
% the first column of the file is a key,
% the second column is a value.
% 
% The function will fail if the property can't be found.
%
%
% Inputs:
%
% fname [char] - the filename path.
% name [char] - an option/mapping name.
% value [char] - an option/mapping value.
%
% Outputs:
%
%
% Example:
%
% file = [toolboxRootPath 'test_updateMappings'];
% nf = fopen(file,'w');
% fprintf(nf,'%s\n','%1st line is a comment');
% fprintf(nf,'%s\n','zero = a');
% fprintf(nf,'%s\n','%3rd line is another comment');
% fprintf(nf,'%s\n','one = b');
% fprintf(nf,'%s\n','%5th line is a comment');
% fprintf(nf,'%s\n','%6th line is also comment');
% fprintf(nf,'%s\n','spam = good');
% fprintf(nf,'%s\n','spam_and_spam = better');
% fprintf(nf,'%s\n','spam_and_eggs = heaven');

% fclose(nf);
% %fail at undefined name.
% try; updateMappings(file,'two','2');catch f=true;end
% assert(f)
%
% %pass - but file is untouched.
% updateMappings(file,'zero','a');
%
% %update pass - file is rewritten, comments are kept.
% updateMappings(file,'spam_and_eggs','and_spam');
% updateMappings(file,'spam_and_spam','and_eggs');
% updateMappings(file,'one',1);
% updateMappings(file,'zero',0);
% opts = readMappings(file,'=');
% assert(strcmpi(opts('zero'),'0'));
% assert(strcmpi(opts('one'),'1'));
% assert(strcmpi(opts('spam'),'good'));
% assert(strcmpi(opts('spam_and_eggs'),'and_spam'));
% assert(strcmpi(opts('spam_and_spam'),'and_eggs'));
% nf = fopen(file,'r');
% text = textscan(nf,'%s','Delimiter','\n');
% text = strip(text{1});
% fclose(nf);
% assert(strcmpi(text{3},'%3rd line is another comment'));
% assert(strcmpi(text{6},'%6th line is also comment'));
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(3,3)
if ~ischar(fname)
    errormsg('First argument not a char')
end
if ~ischar(name)
    errormsg('Second argument not a char')
end

delimiter = detectMappingDelimiter(fname);
nf = fopen(fname,'r');
raw_text = textscan(nf,'%s','Delimiter',delimiter);
if isempty(raw_text)
    errormsg('File %s is empty.',fname);
end
raw_text = raw_text{1};
text = strip(raw_text);
text_value = strip(num2str(value));

[found,cind] = inCell(text,name);
fclose(nf);

if ~found
    errormsg('option %s not in parameter file %s.',name,fname)
end

missing_value = cind+1 > length(text) || strcmpi(text{cind+1}(1),'%');
if missing_value
    errormsg('option %s is missing at file %s.',name,fname);
else
    update_value = cind+1 <= length(text) && ~strcmpi(text{cind+1},text_value);
end

if update_value
    nf = fopen(fname,'w');
    is_name = false;
    for k=1:length(text)
        is_comment = strcmpi(text{k}(1),'%');
        if is_comment
            fprintf(nf,'%s\n',text{k});
            is_name = false;
        elseif ~is_name
            fprintf(nf,['%s ' delimiter ' '],text{k});
            is_name = true;
        else
            is_update = k == cind+1;
            if is_update
                fprintf(nf,'%s\n',text_value);
            else
                fprintf(nf,'%s\n',text{k});
            end
            is_name = false;
        end
    end
    fclose(nf);
end

end
