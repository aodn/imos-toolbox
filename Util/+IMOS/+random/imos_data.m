function [rdata] = imos_data(imos_type, data_size)
% function [rdata] = imos_data(imos_type,data_size)
%
% Generate a random IMOS variable
% given a type and a size.
% A column vector is used if data_size provided
% is singleton.
%
% If no arguments, a double random data of size [100x1]
% is generated.
%
% Inputs:
%
% imos_type [function_handle] - the fh imos type.
% data_size [array] - an size array to use
%                     in the resolution of the data.
%
% Outputs:
%
% rdata [type] - the random data array of specific type
%
% Example:
%
% %random generation 100xN
% [rdata] = IMOS.random.imos_data();
% assert(iscolumn(rdata) && numel(rdata)==100)
%
% %random typed
% [rdata] = IMOS.random.imos_data(@int32);
% assert(isint32(rdata) && iscolumn(rdata) && numel(rdata)==100)
%
% %random typed with defined size
% [rdata] = IMOS.random.imos_data(@int32,[6,1]);
% assert(isint32(rdata) && iscolumn(rdata) && numel(rdata)==6)
% [rdata] = IMOS.random.imos_data(@int32,[1,6]);
% assert(isint32(rdata) && isrow(rdata) && numel(rdata)==6)
% [rdata] = IMOS.random.imos_data(@int32,[6,6]);
% assert(isint32(rdata) && isnumeric(rdata) && numel(rdata)==36)
%
% %invalid type argument
% f=false;try; IMOS.random.imos_data('float');catch;f=true;end
% assert(f)
%
% %invalid size argument
% f=false;try; IMOS.random.imos_data(@double,1);catch;f=true;end
% assert(f)
%
%
% author: hugo.oliveira@utas.edu.au
%

if nargin == 0
    rdata = randn(100, 1);
    return
elseif nargin > 0 && ~isfunctionhandle(imos_type)
    errormsg('First argument `imos_type` is not a function handle')
elseif nargin > 1 && ~issize(data_size)
    errormsg('Second argument `data_size` is not a valid size')
end

if nargin == 1
    rdata = imos_type(randn(100, 1));
else
    rdata = imos_type(randn(data_size));
end

end
