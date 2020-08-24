function [bool] = isint(arg)
	funcs = {@isint8,@isint16,@isint32,@isint64};
	for k=1:length(funcs)
		bool = funcs{k}(arg);
		if bool
			return
		end
	end
end
