%% this scripts investigates the influence of epilepsy on latencies
% Dorien van Blooijs, Dora Hermes, 2020

clc
clear

myDataPath = setLocalDataPath(1);

%% load electrodes file and determine SOZ and RA

% load excel with SOZ locations
[~,~,raw] = xlsread(fullfile(myDataPath.output,'derivatives','M3','SOZRA.xlsx'));

n1Latencies = [];
theseSubs = [];

% load participants.tsv
sub_info = readtable(fullfile(myDataPath.input,'participants.tsv'),'FileType','text','Delimiter','\t','TreatAsEmpty',{'N/A','n/a'});
for kk = 2:size(raw,1)
    
    disp(['subj ' int2str(kk) ' of ' int2str(size(raw,1))])
    
    theseSubs(kk-1).name = ['sub-',raw{kk,2}];
    theseSubs(kk-1).ses = raw{kk,3};
    
    % add subject age
    thisSubName = [theseSubs(kk-1).name];
    n1Latencies(kk-1).id = thisSubName;
    n1Latencies(kk-1).ses = theseSubs(kk-1).ses;
    
    % get number of runs and electrodes info
    n1Latencies(kk-1).elecs_tsv = read_tsv(fullfile(myDataPath.input,[theseSubs(kk-1).name],theseSubs(kk-1).ses,'ieeg',...
        [theseSubs(kk-1).name,'_',theseSubs(kk-1).ses,'_electrodes.tsv']));
    
    % get SOZ
    if ~isnan(raw{kk,5})
        strpar = strsplit(raw{kk,5},',');
        SOZ = NaN(size(strpar));
        for ch = 1:size(strpar,2)
            num = regexp(deblank(strpar{ch}),'[0-9]');
            name = regexp(deblank(lower(strpar{ch})),'[a-z]');
            
            test1 = [deblank(strpar{ch}(name)),deblank(strpar{ch}(num))];
            test2 = [deblank(strpar{ch}(name)),'0',deblank(strpar{ch}(num))];
            
            if ~isempty(find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test1)==1, 1))
                SOZ(ch) = find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test1)==1);
            elseif ~isempty(find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test2)==1, 1))
                SOZ(ch) = find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test2)==1);
            else
                error('SOZ: %s is not found in %s',strpar{ch},thisSubName)
            end
        end
    else
        SOZ  = NaN;
    end
    
    n1Latencies(kk-1).SOZ = SOZ;
    
    % get RA
    if ~isnan(raw{kk,4})
        strpar = strsplit(raw{kk,4},',');
        RA = NaN(size(strpar));
        for ch = 1:size(strpar,2)
            num = regexp(deblank(strpar{ch}),'[0-9]');
            name = regexp(deblank(lower(strpar{ch})),'[a-z]');
            
            test1 = [deblank(strpar{ch}(name)),deblank(strpar{ch}(num))];
            test2 = [deblank(strpar{ch}(name)),'0',deblank(strpar{ch}(num))];
            
            if ~isempty(find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test1)==1, 1))
                RA(ch) = find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test1)==1);
            elseif ~isempty(find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test2)==1, 1))
                RA(ch) = find(strcmpi(n1Latencies(kk-1).elecs_tsv.name,test2)==1);
            else
                error('RA: %s is not found in %s',strpar{ch},thisSubName)
            end
        end
    else
        RA  = NaN;
    end
    
    n1Latencies(kk-1).RA = RA;
    
end

%% load all N1 data
for kk = 1:length(theseSubs)
    disp(['subj ' int2str(kk) ' of ' int2str(length(theseSubs))])
    
    clear thisData
    
    files = dir(fullfile(myDataPath.output,'derivatives','av_ccep',theseSubs(kk).name,theseSubs(kk).ses));
    
    count=1;
    for i=1:size(files,1)
        if contains(files(i).name,'run')
            theseSubs(kk).run{count} = files(i).name;
            count = count+1;
        end
    end
    
    if any(contains(fieldnames(theseSubs),'run'))
        for ll = 1:length(theseSubs(kk).run)
            
            thisRun = fullfile(myDataPath.output,'derivatives','av_ccep',theseSubs(kk).name,theseSubs(kk).ses,...
                theseSubs(kk).run{ll});
            thisData = load(thisRun);
            n1Latencies(kk).run(ll).allLatencies = thisData.tt(thisData.n1_peak_sample(~isnan(thisData.n1_peak_sample)));
            n1Latencies(kk).run(ll).n1_peak_sample = thisData.n1_peak_sample;
            n1Latencies(kk).run(ll).channel_names = thisData.channel_names;
            n1Latencies(kk).run(ll).average_ccep_names = thisData.average_ccep_names;
            n1Latencies(kk).run(ll).good_channels = thisData.good_channels;
            n1Latencies(kk).run(ll).tt = thisData.tt;
            
            stimChPair = [];
            for stim = 1:size(thisData.average_ccep_names,1)
                stimCh{1} = extractBefore(thisData.average_ccep_names{stim},'-');
                stimCh{2} = extractAfter(thisData.average_ccep_names{stim},'-');
                
                for ch=1:2
                   stimChPair(stim,ch) = find(strcmp(stimCh{ch},thisData.channel_names)==1);  
                end
            end
            n1Latencies(kk).run(ll).stimChPair = stimChPair;
            
        end
    end
end


%% distinguish latencies SOZ and nSOZ
clc
close all

figure,
n=1;
% when SOZ is response electrode
for kk=1:size(n1Latencies,2)
    if ~isnan(n1Latencies(kk).SOZ)
        clear respnSOZlat respSOZlat
        
        if ~isempty(n1Latencies(kk).run)
            
            for ll = 1:size(n1Latencies(kk).run,2)
                clear respSOZlatencies respnSOZlatencies
                
                respSOZlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).SOZ,:);
                respSOZlatencies = n1Latencies(kk).run(ll).tt(respSOZlatencies(~isnan(respSOZlatencies)));
                
                nSOZ = setdiff(n1Latencies(kk).run(ll).good_channels,n1Latencies(kk).SOZ);
                respnSOZlatencies = n1Latencies(kk).run(ll).n1_peak_sample(nSOZ,:);
                respnSOZlatencies = n1Latencies(kk).run(ll).tt(respnSOZlatencies(~isnan(respnSOZlatencies)));
                
                respnSOZlat{ll} = respnSOZlatencies;
                respSOZlat{ll} = respSOZlatencies;
            end
            
            n1Latencies(kk).respSOZlatencies = horzcat(respSOZlat{:});
            n1Latencies(kk).respnSOZlatencies = horzcat(respnSOZlat{:});
            if (any(~isnan(n1Latencies(kk).respSOZlatencies )) && any(~isnan(n1Latencies(kk).respnSOZlatencies ))) || (~isempty(n1Latencies(kk).respSOZlatencies) && ~isempty(n1Latencies(kk).respnSOZlatencies))
                n1Latencies(kk).respSOZ_p = ranksum(n1Latencies(kk).respnSOZlatencies,n1Latencies(kk).respSOZlatencies);
                
                fprintf('-- %s: When comparing latency in response SOZ and response nSOZ: p = %1.3f with median stim_SOZ = %1.3f sec and median stim_nSOZ = %1.3f sec\n',...
                    n1Latencies(kk).id, n1Latencies(kk).respSOZ_p, median([n1Latencies(kk).respSOZlatencies]),median([n1Latencies(kk).respnSOZlatencies]))
            end
            
            subplot(3,5,n),
            histogram(n1Latencies(kk).respSOZlatencies)
            hold on,
            histogram(n1Latencies(kk).respnSOZlatencies)
            hold off,
            title(sprintf('%s, p=%1.3f',n1Latencies(kk).id,n1Latencies(kk).respSOZ_p))
            
            n=n+1;
            
        end
    end
end


figure, 
histogram([n1Latencies.respSOZlatencies])
hold on,
histogram([n1Latencies.respnSOZlatencies]), hold off
legend('Reponse SOZ','Response nSOZ')

for kk=1:size(n1Latencies,2)
    respSOZ{kk} = n1Latencies(kk).respSOZlatencies;
    respnSOZ{kk} = n1Latencies(kk).respnSOZlatencies;
    
    groupSOZ{kk} = 0.9*ones(size(n1Latencies(kk).respSOZlatencies))+(kk-1);
    groupnSOZ{kk} = 1.1*ones(size(n1Latencies(kk).respnSOZlatencies))+(kk-1);
end
figure,
boxplot([horzcat(respSOZ{:}),horzcat(respnSOZ{:})],...
    [horzcat(groupSOZ{:}),horzcat(groupnSOZ{:})])
ax = gca;
% ax.XTick = [0:size(n1Latencies,2)+1];
% ax.XTickLabel = [' ',num2cell(1:size(n1Latencies,2)), ' ']

%% violin plot!

count=1;
for kk=1:size(n1Latencies,2)
    
    if ~isempty(n1Latencies(kk).respSOZlatencies)
        respall{count} = n1Latencies(kk).respSOZlatencies*1000;
    else
        respall{count} = -100;
    end
    
    count = count+1;
    if ~isempty(n1Latencies(kk).respnSOZlatencies)
            respall{count} = n1Latencies(kk).respnSOZlatencies*1000;
    else
        respall{count} = -100;
    end
count = count+1;    
end

x = sort(2*[0.8:size(n1Latencies,2), 1.2:size(n1Latencies,2)+1]);
fcol = repmat([0.9 0.9 0.9; 0.2 0.2 0.2],size(n1Latencies,2),1);

figure('Position',[1 2 1920 993]),
violin(respall,'x',x,'bw',1,'facecolor',fcol)

xtext = find(~cellfun('isempty',{n1Latencies(:).respSOZ_p}));

text((xtext*2)-0.5,110*ones(1,size(xtext,2)),cellstr(num2str([n1Latencies(:).respSOZ_p]','%1.3f')))
ax = gca;
ax.XTick = 0:2:(size(n1Latencies,2)+1)*2;
ax.XTickLabel =[{' '}, num2cell(1:size(n1Latencies,2)), {' '}];
ylim([0 130])
xlabel('Patient #')
ylabel('Latency (ms)')
title('Latency in SOZ vs nonSOZ CCEPs')

%% when SOZ is stimulated
for kk=1:size(n1Latencies,2)
    if ~isnan(n1Latencies(kk).SOZ)
        clear stimnSOZlat stimSOZlat
        
        if ~isempty(n1Latencies(kk).run)
            
            for ll = 1:size(n1Latencies(kk).run,2)
                clear stimSOZlatencies stimnSOZlatencies
                
                stimpair = zeros(size(n1Latencies(kk).run(ll).stimChPair,1),size(n1Latencies(kk).SOZ,2));
                for ch = 1:size(n1Latencies(kk).SOZ,2)
                    stimpair(:,ch) = sum(n1Latencies(kk).run(ll).stimChPair == n1Latencies(kk).SOZ(ch),2);
                end
                
                SOZ = sum(stimpair,2);
                SOZ(SOZ>=1)=1;
                SOZ = boolean(SOZ);
                
                stimSOZlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).run(ll).good_channels,SOZ');
                stimSOZlatencies = n1Latencies(kk).run(ll).tt(stimSOZlatencies(~isnan(stimSOZlatencies)));
                
                nSOZ = ~SOZ;
                stimnSOZlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).run(ll).good_channels,nSOZ');
                stimnSOZlatencies = n1Latencies(kk).run(ll).tt(stimnSOZlatencies(~isnan(stimnSOZlatencies)));
                
                stimnSOZlat{ll} = stimnSOZlatencies;
                stimSOZlat{ll} = stimSOZlatencies;
            end
            
            n1Latencies(kk).stimSOZlatencies = horzcat(stimSOZlat{:});
            n1Latencies(kk).stimnSOZlatencies = horzcat(stimnSOZlat{:});
            if (any(~isnan(n1Latencies(kk).stimSOZlatencies )) && any(~isnan(n1Latencies(kk).stimnSOZlatencies ))) || (~isempty(n1Latencies(kk).stimSOZlatencies) && ~isempty(n1Latencies(kk).stimnSOZlatencies))
                n1Latencies(kk).stimSOZ_p = ranksum(n1Latencies(kk).stimnSOZlatencies,n1Latencies(kk).stimSOZlatencies);
                
                fprintf('-- %s: When comparing latency in stimulated SOZ and stimulated nSOZ: p = %1.3f with median stim_SOZ = %1.3f sec and median stim_nSOZ = %1.3f sec\n',...
                    n1Latencies(kk).id, n1Latencies(kk).stimSOZ_p, median([n1Latencies(kk).stimSOZlatencies]),median([n1Latencies(kk).stimnSOZlatencies]))
            end
            
        end
    end
end

figure, 
histogram([n1Latencies.stimSOZlatencies])
hold on,
histogram([n1Latencies.stimnSOZlatencies]), hold off
legend('Stimulated SOZ','Stimulated nSOZ')


%% violin plot!

count=1;
for kk=1:size(n1Latencies,2)
    
    if ~isempty(n1Latencies(kk).stimSOZlatencies)
        stimall{count} = n1Latencies(kk).stimSOZlatencies*1000;
    else
        stimall{count} = -100;
    end
    
    count = count+1;
    if ~isempty(n1Latencies(kk).stimnSOZlatencies)
            stimall{count} = n1Latencies(kk).stimnSOZlatencies*1000;
    else
        stimall{count} = -100;
    end
count = count+1;    
end

x = sort(2*[0.8:size(n1Latencies,2), 1.2:size(n1Latencies,2)+1]);
fcol = repmat([0.9 0.9 0.9; 0.2 0.2 0.2],size(n1Latencies,2),1);

figure('Position',[1 2 1920 993]),
violin(stimall,'x',x,'bw',1,'facecolor',fcol)

xtext = find(~cellfun('isempty',{n1Latencies(:).stimSOZ_p}));

text((xtext*2)-0.5,110*ones(1,size(xtext,2)),cellstr(num2str([n1Latencies(:).stimSOZ_p]','%1.3f')))
ax = gca;
ax.XTick = 0:2:(size(n1Latencies,2)+1)*2;
ax.XTickLabel =[{' '}, num2cell(1:size(n1Latencies,2)), {' '}];
ylim([0 130])
xlabel('Patient #')
ylabel('Latency (ms)')
title('Latency in SOZ vs nonSOZ stimuli')

%% distinguish latencies RA and nRA
clc

% when RA is response electrode
for kk=1:size(n1Latencies,2)
    if ~isnan(n1Latencies(kk).RA)
        clear respnRAlat respRAlat
        
        if ~isempty(n1Latencies(kk).run)
            
            for ll = 1:size(n1Latencies(kk).run,2)
                clear respRAlatencies respnRAlatencies
                
                respRAlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).RA,:);
                respRAlatencies = n1Latencies(kk).run(ll).tt(respRAlatencies(~isnan(respRAlatencies)));
                
                nRA = setdiff(n1Latencies(kk).run(ll).good_channels,n1Latencies(kk).RA);
                respnRAlatencies = n1Latencies(kk).run(ll).n1_peak_sample(nRA,:);
                respnRAlatencies = n1Latencies(kk).run(ll).tt(respnRAlatencies(~isnan(respnRAlatencies)));
                
                respnRAlat{ll} = respnRAlatencies;
                respRAlat{ll} = respRAlatencies;
            end
            
            n1Latencies(kk).respRAlatencies = horzcat(respRAlat{:});
            n1Latencies(kk).respnRAlatencies = horzcat(respnRAlat{:});
        end
    end
end

p = ranksum([n1Latencies.respnRAlatencies],[n1Latencies.respRAlatencies]);
fprintf('-- When comparing latency in response RA and response nRA: p = %1.3f with median resp_RA = %1.3f sec and median resp_nRA = %1.3f sec\n',...
    p,median([n1Latencies.respRAlatencies]),median([n1Latencies.respnRAlatencies]))

figure, 
histogram([n1Latencies.respRAlatencies])
hold on,
histogram([n1Latencies.respnRAlatencies]), hold off
legend('Reponse RA','Response nRA')

% when RA is stimulated
for kk=1:size(n1Latencies,2)
    if ~isnan(n1Latencies(kk).RA)
        clear stimnRAlat stimRAlat
        
        if ~isempty(n1Latencies(kk).run)
            
            for ll = 1:size(n1Latencies(kk).run,2)
                clear stimRAlatencies stimnRAlatencies
                
                stimpair = zeros(size(n1Latencies(kk).run(ll).stimChPair,1),size(n1Latencies(kk).RA,2));
                for ch = 1:size(n1Latencies(kk).RA,2)
                    stimpair(:,ch) = sum(n1Latencies(kk).run(ll).stimChPair == n1Latencies(kk).RA(ch),2);
                end
                
                RA = sum(stimpair,2);
                RA(RA>=1)=1;
                RA = boolean(RA);
                
                stimRAlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).run(ll).good_channels,RA');
                stimRAlatencies = n1Latencies(kk).run(ll).tt(stimRAlatencies(~isnan(stimRAlatencies)));
                
                nRA = ~RA;
                stimnRAlatencies = n1Latencies(kk).run(ll).n1_peak_sample(n1Latencies(kk).run(ll).good_channels,nRA');
                stimnRAlatencies = n1Latencies(kk).run(ll).tt(stimnRAlatencies(~isnan(stimnRAlatencies)));
                
                stimnRAlat{ll} = stimnRAlatencies;
                stimRAlat{ll} = stimRAlatencies;
            end
            
            n1Latencies(kk).stimRAlatencies = horzcat(stimRAlat{:});
            n1Latencies(kk).stimnRAlatencies = horzcat(stimnRAlat{:});
        end
    end
end

p = ranksum([n1Latencies.stimnRAlatencies],[n1Latencies.stimRAlatencies]);
fprintf('-- When comparing latency in stimulated RA and stimulated nRA: p = %1.3f with median stim_RA = %1.3f sec and median stim_nRA = %1.3f sec\n',...
    p, median([n1Latencies.stimRAlatencies]),median([n1Latencies.stimnRAlatencies]))

figure, 
histogram([n1Latencies.stimRAlatencies])
hold on,
histogram([n1Latencies.stimnRAlatencies]), hold off
legend('Stimulated RA','Stimulated nRA')