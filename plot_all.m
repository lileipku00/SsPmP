% script to plot sspmp
% written by Ge Jin
clear;

load seiscmap
lalim=[-11 -7.8];
lolim=[148.8 151.8];

amp = 1;
pick_rad = 0.3;
dist_tol = 0.2;
hrange = [20 36];
seiscmap = seiscmap(5:end,:);
hx = linspace(hrange(1),hrange(2),size(seiscmap,1));

figure(45)
clf
ax = worldmap(lalim, lolim);
set(ax, 'Visible', 'off')
load pngcoastline
geoshow([S.Lat], [S.Lon], 'Color', 'black','linewidth',1)

pointnum = 0;
eventmatfiles = dir('eventmat/*.mat');
for ie = 1:length(eventmatfiles)
	clear sac sacR
	load( ['eventmat/',eventmatfiles(ie).name])

	if ~isfield(sac,'isgood')
		continue;
	end

	beforetime = 10;
	aftertime = 20;
	filt = [0.02 0.5];
	Vp = 6.5;

	stlas = [sac.STLA];
	stlos = [sac.STLO];
	evla = sac(1).EVLA;
	evlo = sac(1).EVLO;
	[avgdist avgazi] = distance(mean(stlas),mean(stlos),sac(1).EVLA,sac(1).EVLO);

    taup_com = ['taup_time -ph S -rayp -deg ',num2str(avgdist),' -h ',num2str(sac(1).EVDP),'> taup_temp'];
	system(taup_com);
	rayp = load('taup_temp');
	rayp = rayp/deg2km(1);

	[dists azis] = distance(stlas,stlos,evla,evlo);
	stnmR = {sacR.KSTNM};

	goodind = find([sac.isgood]);

	plotm(stlas(goodind),stlos(goodind),'bv');
    goodstanum = 0;
	for i =1:length(goodind)
		id = goodind(i);
		t3dt = sac(id).T3 - sac(id).T2;
		if isnan(t3dt)
			continue;
        end
        goodstanum = goodstanum + 1;
		% store the point locations
		t3h = t3dt./2./((Vp^(-2) - rayp^2).^.5);
		pdist = km2deg(tan(asin(rayp*Vp))*t3h);
		[plat plon] = reckon(stlas(goodind(i)),stlos(goodind(i)),pdist,azis(goodind(i)));
		pointcolor = interp1(hx,seiscmap,t3h,'nearest','extrap');
        plotm([stlas(goodind(i)) plat],[stlos(goodind(i)) plon],'k');
		plotm(plat,plon,'ro','markerfacecolor',pointcolor,'markersize',20);
		textm(plat,plon+0.05,sac(goodind(i)).KSTNM);
        pointnum = pointnum+1;
        points(pointnum).lat = plat;
        points(pointnum).lon = plon;
        points(pointnum).ie = ie;
        points(pointnum).depth = t3h;
        points(pointnum).stnm = sac(goodind(i)).KSTNM;

		% store the point waveforms
		taxis = sac(id).B:sac(id).DELTA:sac(id).B+sac(id).DELTA*(sac(id).NPTS-1);
		ind = find(taxis > sac(id).T2 - beforetime & taxis < sac(id).T2 + aftertime);
		data = sac(id).DATA1(ind);
		if isempty(data)
			continue;
		end
		fN = 1/sac(id).DELTA/2;
		[b,a] = butter(2,[filt(1)/fN filt(2)/fN]);
		data = filtfilt(b,a,data);
		data = data./max(abs(data))*amp;
		idR = find(ismember(stnmR,sac(id).KSTNM));
		t = -beforetime:sac(id).DELTA:aftertime;
		syndt = sac(id).T1 - sac(id).T2;
		t3dt = sac(id).T3 - sac(id).T2;
		if length(t) > length(data)
			t = t(1:length(data));
		end
        points(pointnum).data = data;
		points(pointnum).t = t;
		points(pointnum).syndt = syndt;
		points(pointnum).t3dt = t3dt;
		
		idR = find(ismember(stnmR,sac(id).KSTNM));
		if ~isempty(idR)
			dataR = sacR(idR).DATA1(ind);
			dataR = filtfilt(b,a,dataR);
			dataR = dataR./max(abs(dataR))*amp;
		end
        points(pointnum).dataR = dataR;
    end
    if goodstanum > 0
        disp([eventmatfiles(ie).name,...
            ' rayp: ',num2str(rayp),...
            ' azi: ',num2str(avgazi),...
            ' sta:',num2str(goodstanum)]);
    end
	colorbar
	colormap(seiscmap)
	caxis(hrange);
end

gridsize = 0.1;
xnode = lalim(1):gridsize:lalim(2);
ynode = lolim(1):gridsize:lolim(2);
plats = [points.lat];
plons = [points.lon];
depths = [points.depth];
[dgrid,xi,yi] = gridfit(plats,plons,depths,xnode,ynode,'smooth',1);
intd = griddata(plats,plons,depths,xi,yi);
dgrid(find(isnan(intd))) = NaN;
for i = 1:length(xi(:))
    dist = distance(xi(i),yi(i),plats,plons);
    if min(dist) > dist_tol
        dgrid(i) = NaN;
    end
end
figure(88)
clf
ax = worldmap(lalim, lolim);
set(ax, 'Visible', 'off')
% geoshow(xi,yi,dgrid,'DisplayType','texturemap');
surfacem(xi,yi,dgrid);
colorbar
colormap(seiscmap)
caxis([20 40])
load pngcoastline
geoshow([S.Lat], [S.Lon], 'Color', 'black','linewidth',1)


while 1
    figure(45)
    [plat plon bot] = inputm(1);
	if exist('an_h','var')
		delete(an_h)
		clear an_h;
	end
    dist = distance(plat,plon,plats,plons);
    ind = find(dist < pick_rad);
    if bot == 1
       for i = 1:length(ind)
           id = ind(i);
           ie = points(id).ie;
           disp([eventmatfiles(ie).name,',',points(id).stnm,':',...
               num2str(points(id).depth)]);
       end
    end
    if bot == 'q'
        break;
    end
    if bot == 'o'
        figure(89)
		clf
		hold on
		keys = [points(ind).lon];
		mat = [ind(:),keys(:)];
		mat = sortrows(mat,2);
		for i = 1:length(ind)
			id = mat(i,1);
			ie = points(id).ie;
			t = points(id).t;
			data = points(id).data;
			dataR = points(id).dataR;
			t3dt = points(id).t3dt;
			syndt = points(id).syndt;
			offset = i*2;
			plot(t,data + offset);
			data(find(data<0)) = 0;
			area(t,data + offset,offset);
			plot(t,dataR + offset,'r');
			dataR(find(dataR>0)) = 0;
			area(t,dataR + offset,offset,'facecolor','r');
			plot(syndt,offset,'rx','markersize',15);
			plot(t3dt,offset,'rv','markersize',15);
			text(t(1),offset+0.5,[eventmatfiles(ie).name,',',points(id).stnm,':',...
            num2str(points(id).depth)]);
		end
		figure(45)
		[clat clon] = scircle1(plat,plon,pick_rad);
		an_h = plotm(clat,clon,'r','linewidth',2);
    end
    if bot == 'p'
		figure(45)
		[clat clon] = scircle1(plat,plon,pick_rad);
		an_h = plotm(clat,clon,'r','linewidth',2);
		figure(89)
		clf
		hold on
		for i = 1:length(ind)
			id = ind(i);
			ie = points(id).ie;
			t = points(id).t;
			data = points(id).data;
			dataR = points(id).dataR;
			t3dt = points(id).t3dt;
			syndt = points(id).syndt;
			offset = i*2;
			plot(t,data + offset);
			data(find(data<0)) = 0;
			area(t,data + offset,offset);
			plot(t,dataR + offset,'r');
			dataR(find(dataR>0)) = 0;
			area(t,dataR + offset,offset,'facecolor','r');
			plot(syndt,offset,'rx','markersize',15);
			plot(t3dt,offset,'rv','markersize',15);
			text(t(1),offset+0.5,[eventmatfiles(ie).name,',',points(id).stnm,':',...
            num2str(points(id).depth)]);
		end
		[x y] = ginput(1);
		id = ind(round(y/2));
		ie = points(id).ie;
		pick_S(eventmatfiles(ie).name);
    end
    if bot == 'r'
        [temp ind] = min(dist);
        ind
        id = ind; ie = points(id).ie;
        disp([eventmatfiles(ie).name,',',points(id).stnm,':',...
            num2str(points(id).depth)]);
    end
    disp(' ');
end
