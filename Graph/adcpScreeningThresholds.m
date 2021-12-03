function adcpScreeningThresholds(Data,ple)
% some plots to assist with selecting screening threshold for fish
% detection (echo range) and corrmag. For single ping data.
% RDI recommendations:
% correlation magnitude threshold = 64 
% echo range = 50
%plc = plot pcolor plot with cmag failures
% ple = plot pcolor plot with fish threshold failures

if nargin < 2
    disp('Need 2 arguments to run')
    return
end

for a = 1:length(Data)
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
    iucur = getVar(sd.variables, 'UCUR_MAG');
    ivcur = getVar(sd.variables, 'VCUR_MAG');
    
    time = sd.dimensions{itime}.data;
    u = sd.variables{iucur}.data;
    v = sd.variables{ivcur}.data;
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

    %% histogram of the failure values for echo range test:
    ea_fishthresh = 50;
    ea = NaN*ones(4,length(time),length(Bins));
    for b = 1:4
        eval(['ea(b,:,:) = echo' num2str(b) ';'])
    end
    % matrix operation of the UW original code which loops over each timestep
    [B, Ix]=sort(ea,1,'descend'); %sort echo from highest to lowest along each bin
    %step one - really only useful for data in beam coordinates. If one
    %beam fails, then can do 3-beam solutions
    %step 1: Find the beams with the highest and two lowest echo levels
    df1 = squeeze(B(1,:,:)-B(4,:,:)); %get the difference from highest value to lowest

    %step 2: Flags entire bin of velocity data as more than one cell is >
    %threshold, which means three beam solution can't be calculated.
    % Is this test really useful for data that has already been converted to
    % ENU? No, it should not be run as the thresholds used flag out the data
    % for identification of 3-beam solutions
    df2 = squeeze(B(1,:,:)-B(3,:,:)); %get the difference from highest value to second lowest
    ind1=find(df1>ea_fishthresh); % problematic depth cells
    ind2=find(df2>ea_fishthresh); % problematic depth cells
    flagser =  ones(size(bdepth));flagser2 = flagser;
    flagser(ind1) = 4;
    flagser2(ind2) = 4;

    %df is the differences between the highest and lowest echo amplitude values
    %for each of the 4 beams in each bin.
    % we need to know what threshold to use
    
    %let's initially pick a threshold where the cumulative distribution should
    %be flattening out:
    %set the edges vector
    edges = [0:150];
    
    figure(1);clf
    [n,edg,~ ] = histcounts(df1,edges,'Normalization','pdf');
    h=histogram(df1, edges,'Normalization','pdf');
    hold on
    
    %add the recommended threshold
    line([50,50],[0,max(n)])
    text(50+4,max(n),'RDI threshold: 50')
    
    title('Echo range histogram')
    ylabel('Normalized count')
    xlabel('Difference in echo amplitude')
    legend('Echo range', 'Threshold','location','best')
    
    
    %look at means/stdev by depth band:
    if isUpwardLooking
        bdBins = nanmin(depth)-2*BinSize:BinSize:nanmax(depth);
    else
        bdBins = nanmedian(depth)-2*BinSize:BinSize:nanmax(max(bdepth));
    end
    
    figure(4);clf;hold on
    edges = 0:5:100;
    hall = histcounts(df1,edges)/20;
    hall2 = histcounts(df2,edges)/20;
    mn = NaN*zeros(1,length(bdBins));
    mx = mn;stx = mx;mmn = mx;cmfails = mx;
    for b = 1:length(bdBins)-1
        ii = find(bdepth >= bdBins(b)  & bdepth <= bdBins(b+1));
        %calculate sum failures, mean, stdev max for this depth, for those within the
        %edges:
        x = df1(ii);
        xx = df2(ii);
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
        [h,edges] = histcounts(xx,edges);
        ij = h>0;
        y = repmat(bdBins(b),1,sum(ij));
        scl = ceil(h(ij)/max(hall2)*300);
        scatter(edges(ij),y,scl,'r');
    end

    %mean, stdeviation
    p1=plot(mn,bdBins,'k-','linewidth',2);
    p2=plot(mn+stx,bdBins,'r-','linewidth',2);
    p3=plot(mn-stx,bdBins,'r-','linewidth',2);
    p4=plot(mx,bdBins,'g-','linewidth',2);
    p5=plot(mmn,bdBins,'g-','linewidth',2);
    p6=line([ea_fishthresh,ea_fishthresh],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Maximum beam-to-beam Echo Amplitude diff - ' type])
    legend([p1,p2,p3,p4,p5,p6],'Mean','+Std Dev','-Std Dev','max','min','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('EA difference','fontsize',12)
    set(gca,'fontsize',12)
    
    %% now let's do the cmag:
    %correlation magnitude is passed if 2 or more beams pass.
    thr = 64;

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
    
    flagscm =  ones(size(cmag1));
    ind = any(cmag<thr,3);
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
        mmn(b) = min(x);
        mx(b) = max(x);
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
    p6=line([thr,thr],[min(bdBins),max(bdBins)],'Color','m','linewidth',2);
    axis ij;grid
    title(['Correlation magnitude by depth - ' type])
    legend([p1,p2,p3,p4,p5,p6],'Mean','+Std Dev','-Std Dev','max','min','Recommended threshold','location','se')
    ylabel('Depth','fontsize',12)
    xlabel('Correlation magnitude','fontsize',12)
    set(gca,'fontsize',12)
    
    if ple
        figure(5);clf;
%         % pcolor plots
%         subplot(311);hold on
%         p1 = pcolor(time,bdepth',df1');shading flat
%         axis ij
%         grid
        bd = bdepth;bd2=bd;
        bd(flagser<3) = NaN;
%         p2=plot(time,bd,'k.');
        bd2(flagser2<3) = NaN;
%         p3=plot(time,bd2,'r.');
%         p4 = plot([time(1),time(end)],[0,0],'k-');
%         colorbar;caxis([0,60])
%         title(['Echo range with Echo range failures'])
%         xlabel('Time')
%         ylabel('Depth')
%         legend([p1,p2(1),p3(1),p4],'Echo Range','ER1 fail','ER2 fail','Surface')
%         datetick
%         % pcolor plots
%         cmm = squeeze(nanmean(cmag,3));
%         subplot(312);hold on
%         pcolor(time,bdepth',cmm');shading flat
%         caxis([50 100])
%         axis ij
%         grid
        bd3 = bdepth;
        bd3(flagscm<3) = NaN;
%         plot(time,bd3,'k.')
%         plot([time(1),time(end)],[0,0],'k-')
%         colorbar
%         title(['Mean Correlation Magnitude and failures'])
%         xlabel('Time')
%         ylabel('Depth')
%         legend('Cmag','CMAG fail','Surface')
%         datetick
        
        %velocity with all flags
%         subplot(313);hold on
        figure(5);clf;hold on
        p1 = pcolor(time,bdepth',v');shading flat
        caxis([-2 0])
        axis ij
        grid
        p2=plot(time,bd,'k.');
        p3=plot(time,bd2,'r.');
        p4=plot(time,bd3,'g.');
        p5 = plot([time(1),time(end)],[0,0],'k-');
        colorbar
        title(['V with Echo range & cmag failures'])
        xlabel('Time')
        ylabel('Depth')
        legend([p1,p2(1),p3(1),p4(1),p5],'V','ER1 fail','ER2 fail','CMag fail','Surface')
        datetick
        linkaxes
    end
    keyboard
    
end
end