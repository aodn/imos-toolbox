function adcpEnsemblesThresholds(Data,n,threrv,hvthres,vvthres,tilt_thr,ea_thresh,thrcmag)
% some plots to assist with selecting ensembles threshold for cmag, erv,
% percent good (if applicable)
% RDI recommendations:
% correlation magnitude threshold = 64
% error velocity = variable, but start with 0.2


for a = n%1:length(Data)
    if isempty(findstr(Data{a}.instrument,'RDI'))
        continue
    end
    sd = Data{a};
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
    
    time = sd.dimensions{itime}.data;
    u = sd.variables{iucur}.data;
    v = sd.variables{ivcur}.data;
    w = sd.variables{iwcur}.data;
    pressure = sd.variables{ipresrel}.data;
    
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
    
    type = sd.instrument;
    BinSize = sd.meta.binSize; %number of bins
    bdepth = depth - repmat(Bins,length(time),1);
    %look at means/stdev by depth band:
    if isUpwardLooking
        bdBins = nanmin(depth)-2*BinSize:BinSize:nanmax(depth);
    else
        bdBins = nanmedian(depth)-2*BinSize:BinSize:nanmax(max(bdepth));
    end
    
    %% now let's do the error velocity:
    %let's initially pick the recommended threshold:
    type = sd.instrument;
    %     threrv = 80/100;%data is in m/s, therefore threshold is 80/100
    %need to put other values in. Depends on instrument and if WB is 1 or
    %0. See the RDI excel worksheet for each type
    
    erv = sd.variables{ierv}.data;
    
    %set the edges vector
    
    figure(4);clf;hold on
    edges = -1:0.005:1;
    hall = histcounts(erv,edges);
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;stx = mx;mmn = mx;
    for b = 1:length(bdBins)-1
        ii = find(bdepth >= bdBins(b)  & bdepth <= bdBins(b+1));
        %calculate sum failures, mean, stdev max for this depth, for those within the
        %edges:
        x = erv(ii);
        if isempty(x)
            continue
        end
        mn(b) = nanmean(x);
        mmn(b) = nanmin(x);
        mx(b) = nanmax(x);
        stx(b) = nanstd(x);
        [h,edges] = histcounts(x,edges);
        ij = h>0;
        scl = ceil(h(ij)/max(hall)*1500);
        y = repmat(bdBins(b),1,sum(ij));
        scatter(edges(ij),y,scl,'b','filled');
    end
    
    %mean, stdeviation
    mm = nanmean(mn);
    p1=plot(mn,bdBins,'k-','linewidth',2);
    p2=plot(mn+stx,bdBins,'r-','linewidth',2);
    p3=plot(mn-stx,bdBins,'r-','linewidth',2);
    p4=plot(mx,bdBins,'g-','linewidth',2);
    p5=plot(mmn,bdBins,'g-','linewidth',2);
    p6=line([mm+threrv,mm+threrv],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    p7=line([mm-threrv,mm-threrv],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['ErrorVelocity by depth - ' type])
    legend([p1,p2,p3,p4,p5,p6],'Mean','+Std Dev','-Std Dev','max','min','Threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('ERV','fontsize',12)
    set(gca,'fontsize',12)
    
    
    %% now let's do the cmag:
    %correlation magnitude is passed if 2 or more beams pass.
    %     thr = 110;
    if ~isempty(thrcmag)
        %set the edges vector
        edges = [0:2:150];
        figure(2);clf;hold on
        cmag = NaN*ones(length(time),length(Bins),4);
        for b = 1:4
            eval(['cmag(:,:,b) = cmag' num2str(b) ';'])
            h=histogram(cmag(:,:,b), edges,'Normalization','pdf');
        end
        
        grid
        line([thrcmag,thrcmag],[0,max(h.Values)],'Color','m','linewidth',2);
        xlabel('Correlation Magnitude')
        ylabel('Normalized Count')
        title(['Correlation magnitude - ' type])
        legend('Cmag1','Cmag2','Cmag3','Cmag4','Threshold')
        
        flagscm =  ones(size(cmag1));
        ind = any(cmag<thrcmag,3);
        flagscm(ind) = 4;
        
        figure(3);clf;hold on
        edges = 0:5:150;
        hall = histcounts(cmag,edges)/20;
        mn = NaN*zeros(1,length(bdBins));
        mx = mn;stx = mx;mmn = mx;cmfails = mx;
        for b = 1:length(bdBins)-1
            ii = find(bdepth >= bdBins(b)  & bdepth <= bdBins(b+1));
            %calculate sum failures, mean, stdev max for this depth, for those within the
            %edges:
            x = cmag(ii);
            if isempty(x)
                continue
            end
            mn(b) = nanmean(x);
            mmn(b) = nanmin(x);
            mx(b) = nanmax(x);
            stx(b) = nanstd(x);
            [h,edges] = histcounts(x,edges);
            ij = h>0;
            y = repmat(bdBins(b),1,sum(ij));
            scl = ceil(h(ij)/max(hall)*300);
            scatter(edges(ij),y,scl,'b','filled');
        end
        
        %mean, stdeviation
        p1=plot(mn,bdBins,'k-','linewidth',2);
        p2=plot(mn+stx,bdBins,'r-','linewidth',2);
        p3=plot(mn-stx,bdBins,'r-','linewidth',2);
        p4=plot(mx,bdBins,'g-','linewidth',2);
        p5=plot(mmn,bdBins,'g-','linewidth',2);
        p6=line([thrcmag,thrcmag],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
        axis ij;grid
        title(['Correlation magnitude by depth - ' type])
        legend([p1,p2,p3,p4,p5,p6],'Mean','+Std Dev','-Std Dev','max','min','Threshold','location','se')
        ylabel('Depth','fontsize',12)
        xlabel('Correlation magnitude','fontsize',12)
        set(gca,'fontsize',12)
    end
    %% echo intensity test, surface test
    if ~isempty(ea_thresh)
%         ea_thresh = 30;
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
        if isUpwardLooking
            bdBins = 0-2*BinSize:BinSize:nanmax(depth);
            bdplot = 0-2*BinSize:BinSize:0+5*BinSize;
        else
            bdBins = nanmax(depth):BinSize:max(nanmax(bdepth));
%             bdplot = nanmax(depth):BinSize:max(nanmax(bdepth)); 
            %hard code for the only downward looking instrument that sees
            %the bottom
            bdplot =400:BinSize:550;
        end
        figure(6);clf
        nn = NaN*zeros(1,length(bdplot));
        mn = nn;mx = mn;stx = mx;
        for b = 1:length(bdplot)-1
            ii = find(bdea >= bdplot(b)  & bdea <= bdplot(b+1));
            [n,edg,bin ] = histcounts(eadiff(ii),edges);
            %calculate mean, stdev max for this depth, for those within the
            %edges:
            x = eadiff(ii);
            x(bin == 0) = [];
            if isempty(x)
                continue
            end
            mn(b) = nanmean(x);
            mx(b) = nanmax(x);
            stx(b) = nanstd(x);
            subplot(length(bdplot)-1,1,b);hold on
            histogram(eadiff(ii), edges);
            nn(b) = max(n);
        end
        %put a line where threshold is on each
        %set y axis
        yax = [0 max(nn)];
        for b = 1:length(bdplot)-1
            subplot(length(bdplot)-1,1,b)
            ylim(yax)
            plot([ea_thresh ea_thresh],[yax],'r-')
            legend([num2str(bdplot(b)) ' to ' num2str(bdplot(b+1)) 'm bin'],'Recommended threshold')
            ylabel('Count')
        end
        
        subplot(length(bdplot)-1,1,1)
        title(['Echo intensity histogram by depth bin - ' type])
        subplot(length(bdplot)-1,1,b)
        xlabel('Echo intensity diff')
        
        %mean, stdeviation
        figure(7);clf
        plot(mn,bdplot);
        hold on
        plot(mn+stx,bdplot,'r-');
        plot(mx,bdplot,'g-');
        line([ea_thresh,ea_thresh],[min(bdplot),max(bdplot)],'Color','m','linewidth',2);
        axis ij;grid
        title(['Absolute Difference between bins, Echo intensity - ' type])
        legend('Mean','Std Dev','max','Recommended threshold','location','se')
        ylabel('Depth','fontsize',12)
        xlabel('Echo intensity difference','fontsize',12)
        set(gca,'fontsize',12)
    end

        %% horizontal velocity
%     vvthres = 2;
    disp(['Horizontal velocity threshold: ' num2str(hvthres)])
    edges = 0:0.05:7;
    speed = sqrt(u.^2 + v.^2);
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;mnn = mx;stx = mx;
    hall = histcounts(speed,edges)/20;
   figure(9);clf;hold on
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
        [h,edges] = histcounts(x,edges);
        ij = h>0;
        y = repmat(bdBins(b),1,sum(ij));
        scl = ceil(h(ij)/max(hall)*300);
        scatter(edges(ij),y,scl,'b','filled');
    end

    figure(8);clf
    h=histogram(speed, edges,'normalization','pdf');
    line([hvthres,hvthres],[0,max(h.Values)],'Color','m','linewidth',2);
    grid
    title(['Horizontal Velocity - ' type])
    ylabel('Normalized Count','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
    
   figure(9)
   plot(mn,bdBins);
    hold on
    plot(mn+stx,bdBins,'r-');
    plot(mn-stx,bdBins,'r-');
    plot(mx,bdBins,'g-');
    line([hvthres,hvthres],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Horizontal Velocity - ' type])
    legend('Mean','Std Dev','Std Dev','max','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)

    %% vertical velocity
%      vvthres = 1;
    edges = -0.5:0.01:0.5;
    speed = w;
    hall = histcounts(speed,edges)/20;
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;mnn = mx;stx = mx;
   figure(11);clf;hold on
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
        mx(b) = nanmax(x);
        mnn(b) = nanmin(x);
        stx(b) = nanstd(x);
        [h,edges] = histcounts(x,edges);
        ij = h>0;
        y = repmat(bdBins(b),1,sum(ij));
        scl = ceil(h(ij)/max(hall)*300);
        scatter(edges(ij),y,scl,'b','filled');
    end

    figure(10);clf
    h=histogram(speed, edges,'normalization','pdf');
    line([vvthres,vvthres],[0,max(h.Values)],'Color','m','linewidth',2);
    line([-vvthres,-vvthres],[0,max(h.Values)],'Color','m','linewidth',2);
    grid
    title(['Vertical Velocity - ' type])
    ylabel('Normalized Count','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
    
   figure(11)
   plot(mn,bdBins);
    hold on
    plot(mn+stx,bdBins,'r-');
    plot(mn-stx,bdBins,'r-');
    plot(mx,bdBins,'g-');
    plot(mnn,bdBins,'g-');
    line([vvthres,vvthres],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    line([-vvthres,-vvthres],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Vertical Velocity - ' type])
    legend('Mean','Std Dev','Std Dev','max','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Velocity (m/s)','fontsize',12)
    set(gca,'fontsize',12)
   
    %% tilt: nominally > 30 degrees fails
%     tilt_thr = 50;
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
    
%     %% u and v and w with depth
%     % help identify ringing bins - don't think it works at this stage, next
%     % step 
%     figure(3);clf;
%     subplot(131)
%     plot(abs(v),depth,'.')
%     grid
%     axis ij
%     xlabel('Absolute V')
%     ylabel('Depth')
%     subplot(132)
%     plot(abs(u),depth,'.')
%     grid
%     axis ij
%     xlabel('Absolute U')
%     ylabel('Depth')
%     subplot(133)
%     plot(abs(w),depth,'.')
%     grid
%     axis ij
%     xlabel('Absolute W')
%     ylabel('Depth')
%     linkaxes

    %%
    figure(5);clf;
    % pcolor plots
    if ~isempty(thrcmag)
        subplot(311);hold on
    else
        subplot(211);hold on
    end
    p1 = pcolor(time,bdepth',erv');shading flat
    axis ij
    grid
    bd = bdepth;
    bd(erv <= mm+threrv & erv >= mm-threrv) = NaN;
    p2=plot(time,bd,'k.');
    p3 = plot([time(1),time(end)],[0,0],'k-');
    colorbar;caxis([-0.2 0.2])
    title(['ERV with ERV failures'])
    xlabel('Time')
    ylabel('Depth')
    legend([p1,p2(1),p3],'ErrorVel','ERV fail','Surface')
    datetick
    %
    if ~isempty(thrcmag)
        cmm = squeeze(nanmean(cmag,3));
        subplot(312);hold on
        pcolor(time,bdepth',cmm');shading flat
        caxis([50 140])
        axis ij
        grid
        bd3 = bdepth;
        bd3(flagscm<3) = NaN;
        plot(time,bd3,'k.')
        plot([time(1),time(end)],[0,0],'k-')
        colorbar
        title(['Mean Correlation Magnitude and failures'])
        xlabel('Time')
        ylabel('Depth')
        legend('Cmag','CMAG fail','Surface')
        datetick
        subplot(313);hold on
        
    else
        subplot(212);hold on
    end
    %velocity with all flags
    
    p1 = pcolor(time,bdepth',v');shading flat
    caxis([-2 0])
    axis ij
    grid
    p2=plot(time,bd,'k.');
    p5 = plot([time(1),time(end)],[0,0],'k-');
    if ~isempty(thrcmag)
        p4=plot(time,bd3,'g.');
        legend([p1,p2(1),p4(1),p5],'V','ERV fail','CMag fail','Surface')
        title(['V with erv & cmag failures'])
    else
        legend([p1,p2(1),p5],'V','ERV fail','Surface')
        title(['V with erv failures'])
    end
    colorbar
    xlabel('Time')
    ylabel('Depth')
    datetick
    linkaxes
%     keyboard
    
end
end