function adcpThresholds(ppData)
% some plots to assist with selecting threshold values for RDI adcp data
%need to look at:
% echo amplitude threshold for range test (should be around 50)
% correlation magnitude threshold
% Nominally:  > 64 (WH LR 75kHz)
%             > 110 (Ocean Observer 38 kHz NB) 300kHz
%             > 190 (Ocean Observer 38 kHz BB)
% error velocity (nominally > 80cm/s fails for single ping). I think the threshold should
% actually be mean(erv) +/- 80cm/s - see RDI adcp QC note document
% side lobe test
% horizontal velocity
% vertical velocity
% tilt: nominally > 30 degrees fails
for a = 2%1:length(ppData)
    if isempty(findstr(ppData{a}.instrument,'RDI'))
        continue
    end
    sd = ppData{a};
    disp([sd.meta.instrument_model ' ' sd.meta.instrument_serial_no ', ' num2str(sd.meta.depth) 'm'])
    %get the data we need
    itime = getVar(sd.dimensions, 'TIME');
    iheight = getVar(sd.dimensions, 'HEIGHT_ABOVE_SENSOR');
    if iheight == 0
    iheight = getVar(sd.dimensions, 'DIST_ALONG_BEAMS');
    end        
    ipresrel = getVar(sd.variables, 'PRES_REL');
    idepth = getVar(sd.variables, 'DEPTH');
    iucur = getVar(sd.variables, 'UCUR');
    ivcur = getVar(sd.variables, 'VCUR');
    iwcur = getVar(sd.variables, 'WCUR');
    ierv = getVar(sd.variables, 'ECUR');
    if iucur == 0
        %data is raw
        iucur = getVar(sd.variables, 'VEL1');
        ivcur = getVar(sd.variables, 'VEL2');
        iwcur = getVar(sd.variables, 'VEL3');
        ierv = getVar(sd.variables, 'VEL4');        
    end
    
    time = sd.dimensions{itime}.data;
    u = sd.variables{iucur}.data;
    v = sd.variables{ivcur}.data;
    w = sd.variables{iwcur}.data;
    pressure = sd.variables{ipresrel}.data;
    uflags = sd.variables{iucur}.flags;
    tflags = sd.dimensions{itime}.flags;
    %depth 
    if idepth > 0
        depth = sd.variables{idepth}.data;
        
    else
        habs = sd.dimensions{2}.data;
        depth = -1*gsw_z_from_p(pressure,-27);
    end
    depth = double(depth);
    % up or down looking
    Bins    = sd.dimensions{iheight}.data';
    isUpwardLooking = true;
    if all(Bins <= 0), isUpwardLooking = false; end
    
    %cmag
    icmag1 = getVar(sd.variables, 'CMAG1');
    icmag2 = getVar(sd.variables, 'CMAG2');
    icmag3 = getVar(sd.variables, 'CMAG3');
    icmag4 = getVar(sd.variables, 'CMAG4');
    cmag1 = sd.variables{icmag1}.data;
    cmag2 = sd.variables{icmag2}.data;
    cmag3 = sd.variables{icmag3}.data;
    cmag4 = sd.variables{icmag4}.data;
    %echo
    iecho1 = getVar(sd.variables, 'ABSIC1');
    iecho2 = getVar(sd.variables, 'ABSIC2');
    iecho3 = getVar(sd.variables, 'ABSIC3');
    iecho4 = getVar(sd.variables, 'ABSIC4');
    echo1 = sd.variables{iecho1}.data;
    echo2 = sd.variables{iecho2}.data;
    echo3 = sd.variables{iecho3}.data;
    echo4 = sd.variables{iecho4}.data;

    %% histogram of the failure values for echo range test:
    if idepth == 0
        [ ~, df] = adcpWorkhorseEchoRangePP({sd}, '' );
    else
        %use the QC tool, not the pp tool
        [~, ~, ~, df] = imosEchoRangeSetQC( sd, 0 );
    end
    %df is the differences between the highest and lowest echo amplitude values
    %for each of the 4 beams in each bin.
    % we need to know what threshold to use
    
    %let's initially pick a threshold where the cumulative distribution should
    %be flattening out:
    thr = 0.0002;
    df = squeeze(df);
    %set the edges vector
    edges = [0:150];
    
    figure(1);clf
    h=histogram(df, edges,'Normalization','cdf');
    
    [n,edg,~ ] = histcounts(df,edges,'Normalization','cdf');
    ind = logical([0,diff(n) <= thr]);
    thrind = edg(ind);
    %replot
    figure(1);clf
    [n,edg,~ ] = histcounts(df,edges,'Normalization','pdf');
    h=histogram(df, edges,'Normalization','pdf');
    hold on
    
    plot(repmat(thrind(1),1,2),[0,max(n)],'r-')
    ind = find(ind);
    disp(['Echo Range Threshold value: ' num2str(edg(ind(1)))])
    text(thrind(1)+4,max(n),['Suggested threshold: ' num2str(edg(ind(1)))])
    
    title('Echo range histogram')
    ylabel('Normalized count')
    xlabel('Difference in echo amplitude')
    legend('Echo range', 'Threshold')
    
    %% now let's do the cmag:
    %correlation magnitude is passed if 2 or more beams pass.
    %let's initially pick a threshold to suit the instrument:
    type = sd.instrument;
    switch type
        case 'RDI WHS300-I-UG306'
            thr = 64;
        otherwise
            thr = 64;
    end
    disp(['Correlation Mag Threshold value: ' num2str(thr)])

    %set the edges vector
    edges = [0:5:150];
    figure(2);clf;hold on
    cmag = NaN*ones(length(time),length(Bins),4);
    for b = 1:4
        eval(['cmag(:,:,b) = cmag' num2str(b) ';'])
        h=histogram(cmag(:,:,b), edges,'Normalization','pdf');
    end
    
    grid
    line([thr,thr],[0,max(h.Values)],'Color','m','linewidth',2);
    xlabel('Correlation Magnitude')
    ylabel('Normalized Count')
    title(['Correlation magnitude - ' type])
    legend('Cmag1','Cmag2','Cmag3','Cmag4','recommended threshold')
    
%     ifail = squeeze(sum(cmag <= thr,3) >=3) ;
    
    %look at means/stdev by depth band:
    BinSize = sd.meta.binSize; %number of bins
    bdepth = depth - repmat(Bins,length(time),1);
    if isUpwardLooking
        bdBins = nanmin(depth)-2*BinSize:BinSize:nanmax(depth);
    else
        bdBins = nanmedian(depth)-2*BinSize:BinSize:nanmax(max(bdepth));
    end
    bdea = NaN*ones(length(time),length(Bins),4);
    for b = 1:4
        bdea(:,:,b) = bdepth;
    end    

    mn = NaN*zeros(1,length(bdBins));
    mx = mn;stx = mx;mmn = mx;cmfails = mx;
    for b = 1:length(bdBins)-1
        ii = find(bdea >= bdBins(b)  & bdea <= bdBins(b+1));
        %calculate sum failures, mean, stdev max for this depth, for those within the
        %edges:
        x = cmag(ii);
        if isempty(x)
            continue
        end
        mn(b) = nanmean(x);
        mmn(b) = min(x);
        mx(b) = max(x);
        stx(b) = nanstd(x);
    end

    %mean, stdeviation
    figure(3);clf
    plot(mn,bdBins);
    hold on
    plot(mn+stx,bdBins,'r-');
    plot(mx,bdBins,'g-');
    plot(mmn,bdBins,'g-');
    line([thr,thr],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Correlation magnitude by depth - ' type])
    legend('Mean','Std Dev','max','min','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Correlation magnitude','fontsize',12)
    set(gca,'fontsize',12)
    
    %% now let's do the error velocity:
    %let's initially pick the recommended threshold:
    type = sd.instrument;
    switch type
        case 'RDI WHS300-I-UG306'
            thr = 80/100;%data is in m/s, therefore threshold is 80/100
            %need to put other values in. Depends on instrument and if WB is 1 or
            %0. See the RDI excel worksheet for each type
        otherwise
            thr = 80/100; %??
    end
    
    
    erv = sd.variables{ierv}.data;
    
    %set the edges vector
    edges = [-4:0.02:4];
    
    figure(4);clf
    h=histogram(erv, edges,'Normalization','pdf');
    
    [n,edg,~ ] = histcounts(erv,edges,'Normalization','pdf');
    hold on
    minthr = nanmean(erv(:))-thr; maxthr = nanmean(erv(:))+thr;
    ind = logical(edg < nanmean(erv(:))-thr | edg > nanmean(erv(:))+thr);
    thrind = edg(~ind);
    plot(repmat(thrind(1),1,2),[0,max(n)],'r-')
    plot(repmat(thrind(end),1,2),[0,max(n)],'r-')
    ind = find(~ind);
    disp(['Erv threshold range (mean+/-threshold): ' num2str(edg(ind(1))) ' ,' num2str(edg(ind(end)))])
    disp(['Erv threshold: ' num2str(thr)])
    
    text(thrind(end),max(n),['Mean + Suggested threshold, threshold: ' num2str(edg(ind(end))) ', ' num2str(thr)])
    text(thrind(1),max(n),['Mean - Suggested threshold, threshold: ' num2str(edg(ind(1))) ', ' num2str(thr)])
    
    title(['Error Velocity histogram ' type])
    ylabel('Normalized count')
    xlabel('Error Velocity')
    legend('Error Velocity', 'Threshold','location','best')
    %mean, stdeviation
    figure(5);clf
    plot(nanmean(erv),Bins);
    hold on
    plot(nanmean(erv)+nanstd(erv),Bins,'r');
    plot(nanmean(erv)-nanstd(erv),Bins,'r')
    plot(max(erv,[],1),Bins,'g');
    plot(min(erv,[],1),Bins,'g')
    line([nanmean(erv(:))+thr,nanmean(erv(:))+thr],range(Bins),'Color','m','linewidth',2);
    line([nanmean(erv(:))-thr,nanmean(erv(:))-thr],range(Bins),'Color','m','linewidth',2);
    title(['Error velocity - ' type])
    legend('Mean','Std Dev','min/max','Threshold selected','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Error velocity','fontsize',12)
    set(gca,'fontsize',12)
    orient portrait

    %% echo intensity test, surface test, just for surface ADCPs
    if isUpwardLooking
        ea_thresh = 30;
        disp(['Echo Intensity threshold: ' num2str(ea_thresh)])
        ea = NaN*ones(length(time),length(Bins),4);
        for b = 1:4
            eval(['ea(:,:,b) = echo' num2str(b) ';'])
        end
        
        BinSize = sd.meta.binSize; %number of bins
        eadiff = abs(diff(ea,[],2));
        
        %set the edges vector
        edges = [10:5:100];
        
        %look at each depth band near the surface:
        bdea = NaN*ones(length(time),length(Bins)-1,4);
        for b = 1:4
            bdea(:,:,b) = bdepth(:,2:end);
        end
        
        bdBins = 0-2*BinSize:BinSize:nanmax(depth);
        bdplot = 0-2*BinSize:BinSize:0+5*BinSize;
        figure(6);clf
        nn = NaN*zeros(1,length(bdBins));
        mn = nn;mx = mn;stx = mx;
        for b = 1:length(bdBins)-1
            ii = find(bdea >= bdBins(b)  & bdea <= bdBins(b+1));
            [n,edg,bin ] = histcounts(eadiff(ii),edges);
            %calculate mean, stdev max for this depth, for those within the
            %edges:
            x = eadiff(ii);
            x(bin == 0) = [];
            if isempty(x)
                continue
            end
            mn(b) = nanmean(x);
            mx(b) = max(x);
            stx(b) = nanstd(x);
            if bdBins(b) < bdplot(end)
                subplot(length(bdplot)-1,1,b)
                histogram(eadiff(ii), edges);
                nn(b) = max(n);
            end
        end
        %put a line where threshold is on each
        %set y axis
        yax = [0 max(nn)];
        for b = 1:length(bdplot)-1
            subplot(length(bdplot)-1,1,b);hold on
            ylim(yax)
            plot([ea_thresh ea_thresh],[yax],'r-')
            legend([num2str(bdplot(b)) ' to ' num2str(bdplot(b+1)) 'm bin'],'Recommended threshold')
            ylabel('Count')
        end
        
        subplot(length(bdplot)-1,1,1)
        title(['Echo intensity histogram by depth bin - ' type])
        xlabel('Echo intensity diff')
        
        %mean, stdeviation
        figure(7);clf
        plot(mn,bdBins);
        hold on
        plot(mn+stx,bdBins,'r-');
        plot(mx,bdBins,'g-');
        line([ea_thresh,ea_thresh],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
        axis ij;grid
        title(['Absolute Difference between bins, Echo intensity - ' type])
        legend('Mean','Std Dev','max','Recommended threshold','location','se')
        ylabel('Depth','fontsize',12)
        xlabel('Echo intensity difference','fontsize',12)
        set(gca,'fontsize',12)
    else
        figure(6);clf
        figure(7);clf
    end
    %% horizontal velocity
    vvthres = 2;
    disp(['Horizontal velocity threshold: ' num2str(vvthres)])
    edges = 0:0.05:7;
    speed = sqrt(u.^2 + v.^2);
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;mnn = mx;stx = mx;
    for b = 1:length(bdBins)-1
        ii = find(bdepth > bdBins(b) & bdepth <= bdBins(b+1));
        [n,edg,bin ] = histcounts(speed(ii),edges);
        %calculate mean, stdev max for this depth, for those within the
        %edges:
        x = speed(ii);
        x(bin == 0) = [];
        if isempty(x)
            continue
        end
        mn(b) = nanmean(x);
        mx(b) = max(x);
        mnn(b) = min(x);
        stx(b) = nanstd(x);
    end

    figure(8);clf
    h=histogram(speed, edges,'normalization','pdf');
    line([vvthres,vvthres],[0,max(h.Values)],'Color','m','linewidth',2);
    grid
    title(['Horizontal Velocity - ' type])
    ylabel('Normalized Count','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
    
   figure(9);clf;hold on
   plot(mn,bdBins);
    hold on
    plot(mn+stx,bdBins,'r-');
    plot(mn-stx,bdBins,'r-');
    plot(mx,bdBins,'g-');
    line([vvthres,vvthres],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Horizontal Velocity - ' type])
    legend('Mean','Std Dev','Std Dev','max','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)

    %% vertical velocity
     vvthres = 1;
    disp(['Vertical velocity threshold: ' num2str(vvthres)])
    edges = 0:0.05:7;
    speed = w;
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;mnn = mx;stx = mx;
    for b = 1:length(bdBins)-1
        ii = find(bdepth > bdBins(b) & bdepth <= bdBins(b+1));
        [n,edg,bin ] = histcounts(speed(ii),edges);
        %calculate mean, stdev max for this depth, for those within the
        %edges:
        x = speed(ii);
        x(bin == 0) = [];
        if isempty(x)
            continue
        end
        mn(b) = nanmean(x);
        mx(b) = max(x);
        mnn(b) = min(x);
        stx(b) = nanstd(x);
    end

    figure(10);clf
    h=histogram(speed, edges,'normalization','pdf');
    line([vvthres,vvthres],[0,max(h.Values)],'Color','m','linewidth',2);
    grid
    title(['Vertical Velocity - ' type])
    ylabel('Normalized Count','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
    
   figure(11);clf;hold on
   plot(mn,bdBins);
    hold on
    plot(mn+stx,bdBins,'r-');
    plot(mn-stx,bdBins,'r-');
    plot(mx,bdBins,'g-');
    line([vvthres,vvthres],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Vertical Velocity - ' type])
    legend('Mean','Std Dev','Std Dev','max','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
   
    %% tilt: nominally > 30 degrees fails
    tilt_thr = 50;
    disp(['Tilt threshold: ' num2str(tilt_thr)])
        iroll = getVar(sd.variables, 'ROLL');
        ipitch = getVar(sd.variables, 'PITCH');

    roll = sd.variables{iroll}.data;
    pitch = sd.variables{ipitch}.data;
    tilt = acosd(sqrt(1-(sind(roll).^2) - (sind(pitch).^2)));

    figure(12);clf
    plot(time,tilt,'k')
    hold on
    grid
    plot([time(1), time(end)],[tilt_thr,tilt_thr],'r')
    title(['Tilt - ' type])
    legend('Tilt','Recommended Threshold')
    xlabel('Time')
    ylabel('Tilt, degrees')
    
    pause
    
end
end