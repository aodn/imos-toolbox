function [bool,plain_name] = is_numbered_var(name)
    plain_name = name;
    sname = split(name,'_');
    bool = numel(sname) == 2 && ~isnan(str2double(sname{2}));    
    if bool
        plain_name = sname{1};
    end
end