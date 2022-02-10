function adcpThresholdsResults(autoQCData,type)
%% plot the results of application of the aqc thresholds for RDI ADCP
%% now pcolors, here is the erv, but could equally plot the u/v or speed to
% see what's going on. Big plots, so have to be careful not to try too much
% at once.
for a = 1:length(autoQCData)
    if isempty(findstr(autoQCData{a}.instrument,'RDI'))
        continue
    end
   
    disp(autoQCData{a}.meta.instrument_serial_no)
    yn = 'y';
    yn = input('continue with plots for this instrument [y default]?','s');
    if ~isempty(findstr('n',lower(yn)))
        continue
    end
    sd = autoQCData{a};
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
    erv = sd.variables{ierv}.data;
    speed = sqrt(u.^2 + v.^2);
    pressure = sd.variables{ipresrel}.data;
    flags = sd.variables{iucur}.flags;
    %depth 
    Bins    = sd.dimensions{iheight}.data';
    if idepth >0
            depth = repmat(sd.variables{idepth}.data,1,length(Bins)) - repmat(Bins,length(time),1);
    else
        depth = repmat(-1*gsw_z_from_p(pressure,-27),1,length(Bins)) - repmat(Bins,length(time),1);
    end
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
    echo1 = abs(diff(sd.variables{iecho1}.data,[],2));
    echo2 = abs(diff(sd.variables{iecho2}.data,[],2));
    echo3 = abs(diff(sd.variables{iecho3}.data,[],2));
    echo4 = abs(diff(sd.variables{iecho4}.data,[],2));

    
    switch type
        case 'surfacetest'
%             ibd = round(length(Bins)/3);
                ibd = 1;
            bd = depth(:,ibd+1:end);
            fl = flags(:,ibd+1:end);

            %plot the difference between bins of echo ampl average (not bin mapped)
            ea = NaN*ones(length(time),length(Bins)-1,4);
            for b = 1:4
                eval(['ea(:,:,b) = echo' num2str(b) ';'])
            end
            eaa = squeeze(nanmean(ea,3));
            eadiff = abs(eaa(:,ibd:end));
            % plot
            figure(7);clf;hold on
            pcolor(time,bd',eadiff');shading flat
            caxis([0 40])
            axis ij
            grid
            bd(fl<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Difference in Echo Amplitude by bin, Echo Intensity test'])
            xlabel('Time')
            ylabel('Depth')
            legend('EchoAmp','Bad data','Surface')
            
            figure(8);clf;
            subplot(311);hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',v');shading flat
            plot(time,bd,'k.')
            caxis([-2 0.5])
            axis ij
            grid
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('V','Surface')
            
            subplot(312);hold on
            bd = depth;
            bd(flags<3) = NaN;
            vv = v;
            vv(flags>2)=NaN;
            pcolor(time,depth',vv');shading flat
            caxis([-2 0.5])
            axis ij
            grid
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('V','Surface')  
            subplot(313);hold on
            uu = u;
            uu(flags>2)=NaN;
            pcolor(time,depth',uu');shading flat
            caxis([-0.5 0.5])
            axis ij
            grid
            plot([time(1),time(end)],[0,0],'k-')
            legend('U','Surface')  
            colorbar
            xlabel('Time')
            ylabel('Depth')

            linkaxes
            %check the horizontal and vertical velocity thresholds here too
            %while we have the surface data flagged out
            figure(2);clf
            bd = depth;
            bd(flags>=3) = NaN;
            plot(v,bd,'x')
            axis ij
            grid
            xlabel('V')
            ylabel('Depth')
            
            
            %plot of u/v
            u(flags > 2) = NaN;
            v(flags > 2) = NaN;
            figure(12);clf;hold on
            plot(u,v,'x')
            grid
            xlabel('U')
            ylabel('V')
            %plot of velocity
            velocity = u + 1i*v;
            figure(11);clf
            plot(abs(velocity),depth,'x');axis ij
            grid
            xlabel('Velocity')
            ylabel('Depth')
            
            
        case 'echorange'
            [~,~,~, df] = imosEchoRangeSetQC( sd );
            figure(5);clf;hold on
            pcolor(time,depth',squeeze(df)');shading flat
            caxis([0 100])
            axis ij
            grid
            bd = depth;
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Echo range with Echo range failures'])
            xlabel('Time')
            ylabel('Depth')
            legend('Echo Range','Bad data','Surface')
            datetick

            figure(6);clf;hold on
            bd = depth;
            pcolor(time,bd',v');shading flat
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            caxis([-2 0.6])
            axis ij
            grid
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('V','Surface')
            datetick
            
        case 'cmag'
            cm = NaN*ones(length(time),length(Bins),4);
            for b = 1:4
                eval(['cm(:,:,b) = cmag' num2str(b) ';'])
            end
            cmm = squeeze(nanmean(cm,3));
            figure(5);clf;hold on
            pcolor(time,depth',cmm');shading flat
            caxis([60 140])
            axis ij
            grid
            bd = depth;
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Correlation Magnitude and failures'])
            xlabel('Time')
            ylabel('Depth')
            legend('Cmag','Bad data','Surface')
            datetick

            figure(6);clf;hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',v');shading flat
            caxis([-0.6 0.6])
            axis ij
            grid
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('V current','Surface')
            datetick
            
            figure(2);clf
            bd = depth;
            bd(flags>=3) = NaN;
            plot(v,bd,'x')
            axis ij
            grid
            xlabel('V')
            ylabel('Depth')

        case 'erv'
            figure(5);clf;hold on
            pcolor(time,depth',erv');shading flat
            caxis([-0.1 0.1])
            axis ij
            grid
            bd = depth;
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Error Velocity and failures'])
            xlabel('Time')
            ylabel('Depth')
            legend('Erv','Bad data','Surface')
            datetick

            figure(6);clf;hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',v');shading flat
            caxis([-0.6 0.6])
            axis ij
            grid
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('v','Surface')
            datetick
            
            figure(7);clf;hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',u');shading flat
            caxis([-0.6 0.6])
            axis ij
            grid
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('u','Surface')
            datetick
        case 'echo'
            ea = NaN*ones(length(time),length(Bins)-1,4);
            for b = 1:4
                eval(['ea(:,:,b) = echo' num2str(b) ';'])
            end
            eaa = squeeze(nanmean(ea,3));
            figure(5);clf;hold on
            pcolor(time,depth(:,2:end)',eaa');shading flat
            caxis([-20 20])
            axis ij
            grid
            bd = depth;
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Echo amplitude and failures'])
            xlabel('Time')
            ylabel('Depth')
            legend('Echo Amplitude','Bad data','Surface')
            datetick

            figure(6);clf;hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',v');shading flat
            caxis([-0.6 0.6])
            axis ij
            grid
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('v','Surface')
            datetick
        case 'vvel'
            %check the vertical velocities
            flags = sd.variables{iwcur}.flags;
            figure(5);clf;subplot(211);hold on
            pcolor(time,depth',w');shading flat
            caxis([-0.2 0.2])
            axis ij
            grid
            bd = depth;
            bd(flags<3) = NaN;
            plot(time,bd,'k.')
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            title(['Vertical velocity and failures'])
            xlabel('Time')
            ylabel('Depth')
            legend('VVel','Bad data','Surface')
            datetick
    
            ww = w;
            ww(flags>2) = NaN;
            subplot(212);hold on
            bd = depth;
            bd(flags<3) = NaN;
            pcolor(time,depth',ww');shading flat
            caxis([-0.2 0.2])
            axis ij
            grid
            plot([time(1),time(end)],[0,0],'k-')
            colorbar
            xlabel('Time')
            ylabel('Depth')
            legend('VVel','Surface')
            datetick
            linkaxes
            
            figure(6);clf;
            plot(ww,depth,'x')
            grid
            axis ij
            xlabel('W')
            ylabel('Depth')
            
    end
    pause
end
return
   
%% some other bits of plotting code to use:
figure(1);clf

ti = autoQCData{1}.dimensions{1}.data;
u = autoQCData{1}.variables{6}.data;
v = autoQCData{1}.variables{5}.data;
pres = autoQCData{1}.variables{24}.data;

flags = autoQCData{1}.variables{6}.flags;

habs = autoQCData{1}.dimensions{2}.data;
depth = repmat(-1*gsw_z_from_p(pres,-27),1,length(habs)) + repmat(habs,1,length(ti))';

pcolor(ti,depth',u')
shading flat
axis ij
hold on
plot(ti,pres,'k-')
%now flags
d = depth;
d(flags == 1) = NaN;
plot(ti,d,'k.')

colorbar
caxis([-2 2])
% re-check the echorange test by looking at the differences matrix
figure(2);clf

ti = autoQCData{1}.dimensions{1}.data;
ea1 = autoQCData{1}.variables{11}.data;
ea2 = autoQCData{1}.variables{12}.data;
ea3 = autoQCData{1}.variables{13}.data;
ea4 = autoQCData{1}.variables{14}.data;
pres = autoQCData{1}.variables{24}.data;

flags = autoQCData{1}.variables{6}.flags;

habs = autoQCData{1}.dimensions{2}.data;
depth = repmat(-1*gsw_z_from_p(pres,-27),1,length(habs)) + repmat(habs,1,length(ti))';
bins = repmat(1:size(flags,2),size(flags,1),1);

pcolor(ti,depth',ea1')
shading flat
axis ij
hold on
plot(ti,pres,'k-')
%now flags
% d = depth;
% d(flags == 1) = NaN;
% plot(ti,d,'k.')
d = bins;
d(flags == 1) = NaN;
plot(d,'k.')
colorbar
caxis([60 140])

    %% side lobe test
     %default threshold for this test is 0.5, approximately 2 bins removed
     BinSize = sd.meta.binSize; %number of bins
    nBinSize = 0.5; %0.5;
    % by default, in the case of an upward looking ADCP, the distance to
    % surface is the depth of the ADCP
    distanceTransducerToObstacle = depth;
    
    % we handle the case of a downward looking ADCP
    if ~isUpwardLooking
        if isempty(sd.site_nominal_depth) && isempty(sd.site_depth_at_deployment)
            error(['Downward looking ADCP in file ' sd.toolbox_input_file ' => Fill site_nominal_depth or site_depth_at_deployment!']);
        else
            % the distance between transducer and obstacle is not depth anymore but
            % (site_nominal_depth - depth)
            if ~isempty(sd.site_nominal_depth)
                site_nominal_depth = sd.site_nominal_depth;
            end
            if ~isempty(sd.site_depth_at_deployment)
                site_nominal_depth = sd.site_depth_at_deployment;
            end
            distanceTransducerToObstacle = site_nominal_depth - depth;
        end
    end
    % calculate contaminated depth
    %
    % http://www.nortekusa.com/usa/knowledge-center/table-of-contents/doppler-velocity#Sidelobes
    %
    % by default substraction of 1/2*BinSize to the non-contaminated height in order to be
    % conservative and be sure that the first bin below the contaminated depth
    % hasn't been computed from any contaminated signal.
    if isUpwardLooking
        cDepth = distanceTransducerToObstacle - (distanceTransducerToObstacle * cos(sd.meta.beam_angle*pi/180) - nBinSize*BinSize);
    else
        cDepth = site_nominal_depth - (distanceTransducerToObstacle - (distanceTransducerToObstacle * cos(sd.meta.beam_angle*pi/180) - nBinSize*BinSize));
    end
    
    % same flags are given to any variable
    flags = ones(size(u));
    bdepth = depth - repmat(Bins,length(time),1);
    
    % test bins depths against contaminated depth
    if isUpwardLooking
        % upward looking : all bins above the contaminated depth are flagged,
        % except where the maximum bin depth is > 0
        iFail = bdepth <= repmat(cDepth, [1, length(Bins)]);
        iPass = bdepth > repmat(cDepth, [1, length(Bins)]) ;
        iPassDeep = min(bdepth,[],2) > 0;
    else
        % downward looking : all bins below the contaminated depth are flagged,
        % except where the maximum bin depth is < bottom
        iFail = bdepth >= repmat(cDepth, [1, length(Bins)]);
        iPass = bdepth < repmat(cDepth, [1, length(Bins)]);
        iPassDeep = max(bdepth,[],2) < site_nominal_depth;
    end

    flags(iPass) = 1;
    flags(iFail) = 4;
    flags(iPassDeep,:) = 1;

    d = depth;
    d(tflags>2) = NaN;
    cd = cDepth;
    cd(tflags>2) = NaN;
    
    % select a small part do a pcolor plot:
    % half furtherest away:
    ibd = round(length(Bins)/2);
    bd = bdepth(:,ibd+1:end);
    flags = flags(:,ibd+1:end);
    %plot the echo ampl average (already bin mapped)
    ea = NaN*ones(length(time),length(Bins),4);
    for b = 1:4
        eval(['ea(:,:,b) = echo' num2str(b) ';'])
    end
    eaa = squeeze(nanmean(ea,3));
    eadiff = diff(eaa(:,ibd:end),[],2);
    bad = bd;
    bad(flags==1) = NaN;
     % plot
    figure(6);clf;hold on
    pcolor(time,bd',eadiff');shading flat
    caxis([0 60])
    plot(time,d,'b')
    plot(time,cd,'r')
    plot(time,bad,'k.')
    plot([time(1),time(end)],[0,0],'k')
    axis ij
    grid
    colorbar
    title(['Difference in Echo Amplitude by bin, SideLobe cutoff, threshold = ' num2str(nBinSize)])
    xlabel('Time')
    ylabel('Depth')
    legend('EchoAmp','Depth Transducer','Side Lobe cutoff','Surface','Bad data')
    


