%%%%%%%%%%%%%%%%%%%%% SPECIFICATIONS OF THE ANALYSIS %%%%%%%%%%%%%%%%%%%%%%
%% DESCRIPTION
% GLM 3 uses the computational model
% high pass filter is relaxed to 360s to allow the capture of some omega
% variations
clear all;
F.name = 'SPM12_R6RETROICOR_2ROI_HP96_catPE_prior1_tercile'; % name of the GLM - first level

%% preliminaries
if strcmp(computer, 'GLNXA64')
else
end
run('BEHAVIOR/all_subject_info.m');
load('BEHAVIOR/modeling_seq_final/o_MBtype2_wOM2_bDEC1_nobound_e_aSASSSSAS1_aOMIntInf1_prior1_28-Jun-2021_1/fitted_model.mat');
load('generic_out');

%% Global definition

F.subjnames = B.subjnames;
F.subjnames = sort(F.subjnames); % alphabetical order

%%%%%%% FIRST LEVEL

F.iterations = 0; % 0 = no iteration / 1 = iterations
F.runid = [1 2 3 4]; % runs to be analyzed
F.prprcpref = 's6wau'; % prefix of epidata
F.prprcsuf = '.nii'; % suffix of epidata (.img or .nii)
F.mvtpref = 'R6RETROICOR_2ROI_';     % prefix of the motion txt file simplest: rp_
F.mvtsuff = '.mat'; % simplest .txt
F.mvtind = 4;
F.mask = '';%cellstr(spm_select('FPList', '/home/control/romlig/SASSS_fMRI1/LEVEL0', ['.*brainmask_binarized'])); % mask used for analysis (optional )
F.brainmask = '';
F.implicit_threshold = 0.1;
F.hpf = 96; % high pass filter period
F.hrf_derivs = [0 0]; % 1 or 0 [temporal dispersion]

% recap nuisance regressors
% {1} = 'R6_' 
% {2} = ['R6_2ROI_'
% {3} = ['R6RETROICOR_'
% {4} = ['R6RETROICOR_2ROI_' 
% {5} = ['R12_'
% {6} = ['R12_2ROI_'
% {7} = ['R12RETROICOR_'
% {8} = ['R12RETROICOR_2ROI_'
% {9} = ['R12_2ROI_' 
% {10} = ['R24_2ROI_' 
% {11} = ['R24RETROICOR_'
% {12} = ['R24RETROICOR_2ROI_' 
        
F.units = 'secs'; % ('secs' or 'scans')        %       
F.RT = 0.7; % in secs ('secs' or scans)
F.fmri_t = 64; % number of slices (cermep = 26)
F.fmri_t0 = 2; % microtime onset / first slice (cermep = 13)
F.FIR.do = 0;
% if exist('estimate_firstlev_step', 'var')
% F.doest = estimate_firstlev_step;
% else
%     F.doest = 1;
% end;

F.contrastleft = {};
F.contrastright = {};

F.estfunc = 'spm_spm'; % or spm_spm_Bayes or spm_spm_quickest
% F.check_imgsuf =['.*ResMS.img'];
% F.check_roidir = '';
% F.check_roisuf = ['.*img'];

%%%%% COMMON INFO

F.mpath = '/project/3017049.01/SASSS_fMRI1/';
F.prprcpath = 'fMRI_NII/';
F.prprcspec = 'LEVEL0/preprocess_relocate_23-Jul-2019_32s.mat';
F.nuisancepath = 'LEVEL0/final_regressors/';
F.behavpath = 'LEVEL1/converted_logfiles/';
F.anaspecs =  'LEVEL1/GLM_specifications/';
F.firstlevpath = [F.mpath 'LEVEL1/' F.name '/'];
F.secondlevpath = [F.mpath 'LEVEL2/' F.name '/']; % all these path are subpaths from mpath
F.spmpath =  '/project/3017049.01/Tools/spm12/'; % full spm path
F.homefunc = '/project/3017049.01/SASSS_fMRI1/Pipelines/functions'; % full path to homemade functions.
F.vbapath = '/project/3017049.01/Tools/VBA-toolbox/';
F.marsbarpath = []; %'toolbox/marsbar/'; % puzzling with spm8 estimation
% if exist([F.firstlevpath 'RUN_MAT/'], 'dir') ==0; mkdir([F.firstlevpath 'RUN_MAT/']);end;
% if exist([F.firstlevpath 'BEHAV_ANALYSIS/'], 'dir') ==0; mkdir([F.firstlevpath 'BEHAV_ANALYSIS/']);end;

load([F.mpath F.prprcspec], 'I');
addpath(genpath(F.vbapath))

%% header stuff
shead = { 't' 'L.streak(r)' 'r' 'E.cond(r)' 'noise1' 'noise2', 'noise3', 'state' 'snext' 'smax' 'violation' 'side' 'resp_side' 'resp_RT' 'resp_choice' 'warning' 'post_jitter' 'trial_onset' 'resp_onset' 'fade_onset' 'fade_offset'}';
phead = { 't' 'tt' 'ttt' 'L.streak(r)' 'r' 'E.cond(r)' 'noise1', 'noise2', 'noise3', 'p','state','hyp_LR' 'resp_side' 'resp_RT' 'resp_choice' 'correct_resp' 'resp_acc' 'feedback' 'warning' 'post_jitter' 'trial_onset' 'resp_onset' 'post_onset' 'post_offset'}';
display('%%%%%% standard header / shead %%%%%%')
shead = strcat(num2str([1:numel(shead)]'), '-', shead)
display('%%%%%% predictive header / phead %%%%%%')
phead = strcat(num2str([1:numel(phead)]'), '-', phead)


%% Do the job
% try rmdir(F.firstlevpath, 's');end
summed_r = zeros(4);

% add mi to path
omega_ind = 49;
intInf_ind = 52;

for s = 1:32;
    
    sdir = [F.firstlevpath sprintf('%03d',s) '/'];mkdir(sdir);
        
    for r = 1:4
        
        dummat = [];
        clear pmod onsets names orth durations
        %%% build model-based regressors
        % omega is directly extracted from hidden states
        % it is therefore as long as the 'cond' 
        block_ind = [find(isnan(out{s}.u(1,:)) | out{s}.u(1,:)==0) length(out{s}.u(1,:))+1];
        block_idx = block_ind(r):block_ind(r+1);
        omegaraw = muX{s}(omega_ind,block_ind(r):block_ind(r+1)-1);
        omega = muX{s}(omega_ind,block_ind(r):block_ind(r+1)-1);
        
        omega_prv = [0 muX{s}(omega_ind,block_ind(r):block_ind(r+1)-2)];

        P_obsf = phiFitted;
         in_obsf = options.inG;
         
        % 
        sigomega = VBA_sigmoid(omegaraw, 'slope', phiFitted(s,2), 'center', phiFitted(s,3));       
        
         omegaPE = [0 diff(omegaraw)];
       
         SSpe= 0;
         SASpe = 0;
        state_repeat=0;
        t = 0;
        for tt = block_ind(r):block_ind(r+1)-1
            t = t+1;
            if out{s}.u(1,tt)==1 && tt~=block_ind(r)
                % previous state
                prv_s = out{s}.u(2,tt);
                prv_c = out{s}.u(4,tt);
                cur_s = out{s}.u(11,tt);
                state_repeat(t)=double(prv_s==cur_s);
                SSpe(t) =muX{s}(in_obsf.hs.map.SS(prv_s,cur_s),tt)-muX{s}(in_obsf.hs.map.SS(prv_s,cur_s),tt-1);
                SASpe(t) = muX{s}(in_obsf.hs.map.SAS{prv_c}(prv_s,cur_s),tt)-muX{s}(in_obsf.hs.map.SAS{prv_c}(prv_s,cur_s),tt-1);
            else
                 SSpe(t) = NaN;
                 SASpe(t) = NaN;
                state_repeat(t)=NaN;
            end  
        end

        cond_ind = out{s}.u(10,block_ind(r):block_ind(r+1)-1);
        cond_ind(1:8:end)=3;

        % for the other model variables, we need to perform other
        % computations; it could be done by using the u matrix too, but we adopt
        % a different approach based on logfile info.
        load([B.mdir 'task_DATA/' B.SSAS{r}{s,1}],'L', 'E');
        
        choice_std = L.predict.log(:,15);
  
        
        %%%%%%%%%%%% define all possible onsets
        %
        T.std_onset = L.explore.log(:,18)-L.start_time; 
        R.run_durations(s,r)=T.std_onset(end)/60;
        R.run_trials(s,r) = numel(T.std_onset);
        %
        T.warn_onset = T.std_onset(find(L.explore.log(:,16)));
        % 
        T.stdresp_onset = L.explore.log(:,19)-L.start_time;
        %
        T.prd_onset = L.predict.log(:,21)-L.start_time; 
        T.prdfb_onset = L.predict.log(L.predict.log(:,18)==1,24)-1-L.start_time; 
        % 
        T.prdresp_onset = L.predict.log(:,22)-L.start_time; 
        
        %%%%%% categorical splits
        
        %%% feedbacks
        prd_fb = [];
        for t = 1:size(L.predict.log,1)
            if L.predict.log(t,18)==1
                if L.predict.log(t,17)==1
                    prd_fb(t,1) = 1;
                else
                    prd_fb(t,1) = -1;
                end
            else
                prd_fb(t,1) = 0;
            end
        end
                   
        T.prdfb_onset_pos = L.predict.log(prd_fb==1,24)-1-L.start_time; 
        R.fb_pos(s,r) = numel(T.prdfb_onset_pos);
        T.prdfb_onset_neg = L.predict.log(prd_fb==-1,24)-1-L.start_time; 
        R.fb_neg(s,r) = numel(T.prdfb_onset_neg);
        T.prdfb_onset_neutral = L.predict.log(prd_fb==0,24)-1-L.start_time;
        T.prdfb_onset = L.predict.log(:,24)-1-L.start_time;               
        
        %%% standard trials by devL.explore.log(:,11)<2iants & condition for categorical analysis
        deviant = 0;
        for t = 2:size(L.explore.log,1)
            deviant(t,1) = double(L.explore.log(t,8)~= L.explore.log(t-1,10));
        end

        %%% determine the control representations in predictive trials
        prd_control = [];
        for t = 1:2:size(L.predict.log)
            prd_control(t:t+1) = (L.predict.log(t,15)==L.predict.log(t+1,15));
        end
        
        R.deviant_freq(s,r) = nanmean(deviant);       
        R.deviant_freq_C(s,r) = nanmean(deviant(L.explore.log(:,4)>2));       
        R.deviant_freq_UC(s,r) = nanmean(deviant(L.explore.log(:,4)<3));       
        % 
        normal_C_ind = L.explore.log(:,11)<2 & deviant(:,1)==0 & L.explore.log(:,4)>2;
        normal_UC_ind = L.explore.log(:,11)<2 & deviant(:,1)==0 & L.explore.log(:,4)<3;
        deviant_C_ind = L.explore.log(:,11)<2 & deviant(:,1)==1 & L.explore.log(:,4)>2;
        deviant_UC_ind = L.explore.log(:,11)<2 & deviant(:,1)==1 & L.explore.log(:,4)<3;
        
        T.std_onset5_normal_C = T.std_onset(normal_C_ind);
        T.std_onset5_normal_UC = T.std_onset(normal_UC_ind);
        T.std_onset5_deviant_C = T.std_onset(deviant_C_ind);
        T.std_onset5_deviant_UC = T.std_onset(deviant_UC_ind);
        T.std_onset1 = T.std_onset(1:6:end);
       
            
        %%% pred trial by condition
        T.prd_onset_C = T.prd_onset(L.predict.log(:,6)>2);
        T.prd_onset_UC = T.prd_onset(L.predict.log(:,6)<3);
            
        %%% all motor resp
        T.motor = [T.stdresp_onset; T.prdresp_onset];
        
        %%%%%%%% Define parametric regressors
        %%% RT
        std_RT = log(L.explore.log(:,14));
        prd_RT = log(L.predict.log(:,14));
        std_cond_ind = cond_ind(cond_ind~=2);
        std1_RT = std_RT(std_cond_ind==3);
        std_RT = std_RT(std_cond_ind==1);
        

        std_omega = omega(cond_ind<2)';
        std_sigomega = sigomega(cond_ind<2)';
        std_omega_prv = omega_prv(cond_ind<2)';
        
        % previous omega
        std1_omega = omega(cond_ind==3)';

  
        std_SSpe = SSpe(cond_ind<2);
        std_SASpe = SASpe(cond_ind<2);
        std_state_repeat = state_repeat(cond_ind<2);

        std_omegaPE = omegaPE(cond_ind<2)';
      
        prd_omega = omega(cond_ind==2);
        prd_sigomega = sigomega(cond_ind==2);

        state = L.explore.log(:,8);
        std_muX = muX{s}(:,cond_ind<2);
        
        n=0;
        
        SS_bool = std_SSpe>prctile(std_SSpe,200/3);
        SAS_bool = std_SASpe>prctile(std_SASpe,200/3);
        
        ind_both = find(SS_bool & SAS_bool);
        ind_none = find(~SS_bool & ~SAS_bool)   ;     
        ind_SS = find(SS_bool & ~SAS_bool)  ;      
        ind_SAS = find(SAS_bool & ~SS_bool)  ;      
        
        controlcond=L.explore.log(:,4)>2;
        std5_controlcond=controlcond;
        std5_controlcond(1:6:end)=[];
        SSnoSAS_control(s,r)=sum(std5_controlcond(SS_bool & ~SAS_bool));
        SASnoSS_control(s,r)=sum(std5_controlcond(~SS_bool & SAS_bool));
        
        SSnoSAS(s,r)=sum(SS_bool & ~SAS_bool);
        SASnoSS(s,r)=sum(~SS_bool & SAS_bool);
        
        
        [coefR p] = corr(std_SSpe',std_SASpe');
        
        keep_corr(s,r)=coefR(1);
                
        pmod(5).name{1} = 'prd_omega';
        pmod(5).param{1} = zscore(prd_sigomega');
        pmod(5).poly{1} = 1;
        
        pmod(5).name{2} = 'prd_RT';
        pmod(5).param{2} = zscore(prd_RT);
        pmod(5).poly{2} = 1;
                 
        %%%%%%%%% Create RUN_MAT file

        %%% names
        names{1} = 'std_noPE';
        names{2} = 'std_bothPE';
        names{3} = 'std_ssPE';
        names{4} = 'std_sasPE';
        names{5} = 'prd';
        names{6} = 'prd_fb_neutral';
        names{7} = 'prd_fb_pos';
        names{8} = 'prd_fb_neg';        
        names{9} = 'motor';
        names{10} = 'std1';
       
        %%% specify orthogonalization per condition
        orth = repmat({false}, length(names),1);
         orth{1} = false;
         orth{2} = false;
        
        %%% durations
        durations(1:length(names)) = {0};

        %%% onsets
        std5onsets = T.std_onset; 
        std5onsets(1:6:end) = [];
        onsets{1} = unique([std5onsets(ind_none)]);   
        onsets{2} = std5onsets(ind_both);
        onsets{3} = std5onsets(ind_SS);
        onsets{4} = std5onsets(ind_SAS);
        onsets{5} = T.prd_onset;
        onsets{6} = T.prdfb_onset_neutral;
        onsets{7} = T.prdfb_onset_pos;
        onsets{8} = T.prdfb_onset_neg;
        onsets{9} = T.motor;
        onsets{10} = T.std_onset1;
        
        n_trials_SS(s,r)=length(ind_SS);
        n_trials_SAS(s,r)=length(ind_SAS);
        
        %%% screen and remove empty regressors
        exclude_reg = [];
        for o = 1:length(onsets)
            if isempty(onsets{o});
                exclude_reg(end+1)=o;
                disp(['subject ' num2str(s) ': ' names{o} ' missing in run ' num2str(r) '!'])
            end
        end
        onsets(exclude_reg)=[];names(exclude_reg)=[];durations(exclude_reg)=[];
        orth(exclude_reg) = [];
        try
            pmod(exclude_reg) = [];
        end
        
        %%% save GLM
        save([sdir sprintf('%03d',s) '_runmat_b' num2str(r) '.mat'], 'names', 'onsets', 'durations', 'pmod', 'orth');
        F.run_mat{s}{r} = [sdir sprintf('%03d',s) '_runmat_b' num2str(r) '.mat'];

    end
end

% summed_r/(32*4)

save([F.firstlevpath 'infos_FIPRT.mat'], 'F', 'I', 'R', 'T');
