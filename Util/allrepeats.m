function [bind] = allrepeats(array)
% function [] = allrepeats(array)
%
% Inclusive find of all repeated 
% values within an array.
%
% Inputs:
% 
% array - the array
%
% Outputs:
% 
% bind - indexes where of repeated
%        values, including the first
%        item.
%
% Example:
%
% %basic usage
% bind = allrepeats([1,2,3,1,5,1]);
% assert(any(bind));
% assert(isequal(bind,[1,4,6]));
%
% %no repeats
% assert(~any(allrepeats([1,2,3])))
%
% author: hugo.oliveira@utas.edu.au
%
if ~isnumeric(array)
	error('%s: first argument is not a numeric array',mfilename);
end
bind = [];
[uniq,~,uind] = isunique(array);
if ~uniq 
	aind = 1:numel(array);
	repeats = array(setdiff(aind,uind));
	bind = find(ismember(array,repeats));
end
