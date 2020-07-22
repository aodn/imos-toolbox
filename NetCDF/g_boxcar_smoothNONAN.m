function Xsmo = g_boxcar_smoothNONAN(X,n)


% Xsmo = g_boxcar_smoothNONAN(X,n)
%
% This function performs a 1-D boxcar running average of the variable X,
% smoothing the columns with the length of the boxcar filter n.
% It uses the conv2 function and boxcar.
% The ends of X, which are influenced by the zero-padding performed by
% conv2, are substituted with un-smoothed data from X, so that Xsmo
% is the same length of X and doesn't include any crappy data.

% interpolating over NaN's in X *(between columns),
% then replacing after smoothing.

% TODO: change this to only blank out when one block of data is longer than
% x% of the averaging interval.

% ok, we need to divide areas with too many nan's from areas that have only
% smaller blocks of nan's. how do we define this? There could be every data
% point missing, but the time series would still be fine. However, if the
% missing data lie all within one big block, this area will have really bad
% data...

% look for blocks of nan's each block should be shorter than half the
% averaging interval to be interpolated over. also, make sure that data
% before and after the block are not much smaller than the block itself.




Inn  = find(isnan(X));
Inn2 = isnan(X);
isrl = isreal(X);

Xi   = NaN.*X;
dumm = 1:size(X,2);

for j=1:size(X,1);
    Ibb = find(~isnan(X(j,:)));
    if length(Ibb)>2
        Xin=interp1(dumm(Ibb),X(j,(Ibb)),dumm,'linear');
        Xi(j,:)=Xin;
    else
        if isrl
            Xi(j,:)=NaN;
        else
            Xi(j,:) = NaN + NaN * i;
        end
    end
end

% Xi=X;

bb = boxcar(n)./sum(boxcar(n));
Xa = conv2(1,bb',Xi,'same');
if isrl
    Xsmo = Xi.*NaN;
else
    Xsmo = Xi.* (NaN + NaN * i);
end
Xsmo(:,ceil(n./2):end-ceil(n./2)) = Xa(:,ceil(n./2):end-ceil(n./2));


% % Xsmo(Inn)=NaN;
% 
% % Go through each row and check the length of nan blocks
% for jj = 1:size(X,1);
%   nn = Inn2(jj,:);
%   nn2 = nn;
%   nn2(nn==1) = 0;
%   [l, ia, ib, ~] = blocklen(nn(:));
%   ll = l(ia);
%   if length(ia)>2
%   ln = nn(ia);
%   xl = find(ll(:)>=n/2 & ln(:)==1);
%   for ii = 2:length(xl)-1
%     if ll(xl(ii)-1)<n/2 || ll(xl(ii)+1)<n/2
%       nn2(ia(xl(ii)):ib(xl(ii))) = 1;
%     elseif ll(xl(ii)-1)>n/2 && ll(xl(ii)+1)>n/2
%       nn2(ia(xl(ii)):ib(xl(ii))) = 0;
%     end
%   end
%   end
% Xsmo(jj,nn2) = NaN;
%   
% end


% Go through each row and check the length of nan blocks
for jj = 1:size(X,1)
    nn = Inn2(jj,:);
    nn2 = nn;
    [l, ia, ib, ~] = blocklen(nn(:));
    ll = l(ia);
    if length(ia)>2
        ln = nn(ia);
        %   xl = find(ll(:)>=n/2 & ln(:)==1);
        xl = find(ln(:)==1);
        for ii = 2:length(xl)-1
            if ll(xl(ii))>n
                nn2(ia(xl(ii)):ib(xl(ii))) = 1;
            elseif ll(xl(ii))<n/2
                nn2(ia(xl(ii)):ib(xl(ii))) = 0;
            elseif ll(xl(ii)-1)<n/2 || ll(xl(ii)+1)<n/2
                nn2(ia(xl(ii)):ib(xl(ii))) = 1;
            elseif ll(xl(ii)-1)>n/2 && ll(xl(ii)+1)>n/2
                nn2(ia(xl(ii)):ib(xl(ii))) = 0;
            end
        end
    end
    if isrl
        Xsmo(jj,nn2) = NaN;
    else
        Xsmo(jj,nn2) = NaN + NaN*i;
    end
end
