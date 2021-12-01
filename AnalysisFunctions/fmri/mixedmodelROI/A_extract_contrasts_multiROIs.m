%%
clear all
close all

addpath('/project/3017049.01/Tools/spm12')
addpath('/project/3017049.01/Tools/functions/gramm-master')
rmpath(genpath('/project/3017049.01/Tools/spm12/external/fieldtrip/'))
%% where are the volumes from which the signal should be extracted
tic

disp('multiROIs multifolders: preprocessing');
basedir = '/project/3017049.01/SASSS_fMRI1/LEVEL1//';
subdirs = {'SPM12_R6RETROICOR_2ROI_HP96_diff_prior1_ter/',...
           'SPM12_GLM30abssigned_R6RETROICOR_2ROI_HP96_bis/',...
           'SPM12_GLM30ssbis_R6RETROICOR_2ROI_HP96_bis/',...
           'SPM12_GLM30sasbis_R6RETROICOR_2ROI_HP96_bis/'};
subpattern = {'std5xstd_PEdiff^1*bf(1)',...
              'std5xstd_ssPE^1*bf(1)',...
              'std5xstd_sasPE^1*bf(1)'}
subdirs=subdirs(1);
subpattern=subpattern(1);
pattern_pref = '';
subset_subj = 1:32;%find(controlACC>median(controlACC));

% gather all files
filenames={};
for d = 1:length(subdirs)
    load([basedir subdirs{d} 'C.mat'])
    cind= strmatch(subpattern{d}, C.regressor_list, 'exact');
    for s=1:length(subset_subj)
        filenames{d}{s,1}=[basedir subdirs{d} sprintf('%0.3i/',subset_subj(s)) C.con_id{subset_subj(s),cind}];
    end
%     
%     
%     targetdir = [basedir subdirs{d}];
%     dummy = dir(targetdir);
%     dummy = {dummy.name}';
%     cellsz = 1-cell2mat(cellfun(@isempty,regexpi(dummy,['^' pattern_pref '.*' pattern_suff]),'uni',false));
%     filenames{d} = dummy(find(cellsz));
end
    
%% where are the ROIs from which the signal should be extracted
% they should all be in the same location

roidir = '/project/3017049.01/SASSS_fMRI1/VOI_analysis/ROIimages/DiffPE/';
%  roidir = '/project/3017049.01/SASSS_fMRI1/VOI_analysis/ROIimages/Old/Anatomical_ROIs_subset/rPauli2018_SNVTA/';
% roidir='/project/3017049.01/SASSS_fMRI1/VOI_analysis/ROIimages/p0001_all/ModelsOfInterestPEsimple/';
 roilist = 'all'; % 'all' for all images in folder. cellstr of exact names (no extension) otherwise
roi_ext = '.nii';
pattern_suff = '.nii';

if strcmp(roilist,'all')
    dummy = dir(roidir);
    dummy = {dummy.name}';
    cellsz = 1-cell2mat(cellfun(@isempty,regexpi(dummy,['^.*' pattern_suff]),'uni',false));    
    roinames = dummy(find(cellsz));
else
    roinames = roilist;
end

% roinames=roinames(1:4);

%% do the extraction job
result_table = table();

for r=1:length(roinames)
    
    disp(['multiROIs multifolders: ' roinames{r}]);

    % open the roi file
    ROI = spm_vol([roidir roinames{r}]);
    [R XYZ] = spm_read_vols(ROI);
    roi_ind = find(R>0);
    R_XYZ = XYZ(:,roi_ind);
        
    for d=1:length(subdirs)
        
        % obtain image space from first file
        VOL = spm_vol([filenames{d}{1}]);
        [V XYZ] = spm_read_vols(ROI);
        roi2vol_ind = nan(1,size(R_XYZ,2));
        for vx=1:size(R_XYZ,2)
           [dum,roi2vol_ind(vx)] = spm_XYZreg('NearestXYZ',R_XYZ(:,vx),XYZ);
%            VOL_XYZmm(:,vx)=dum;
        end
        [x,y,z] = ind2sub(size(V),roi2vol_ind);
        XYZvx = [x;y;z];
        
        % obtain all voxel values
        [extdata] = spm_get_data(cellstr(strcat(char(filenames{d}))),XYZvx,true);
        
        % build the fields
        Roi = repmat(cellstr(roinames{r}(1:end-4)),size(extdata,1),1);
        Folder = repmat(cellstr(subpattern{d}),size(extdata,1),1);   
        Target =filenames{d}; 
        Mean = nanmean(extdata,2);
        Std = nanstd(extdata,[],2);
        Median = nanmedian(extdata,2);  
        Subindex = [1:size(extdata,1)]';
        keepMean(:,r) = nanmean(extdata,2);

        % apply summary statistics across voxels and make a table
        result_table = [result_table; table(Roi,Folder, Target, Mean, Std, Median, Subindex)];
        
    end
    
    toc;
    
end
        
% plot per ROI per folder
figure('Name', 'ROI as X, Folder as Color');
clear g
g=gramm('x', result_table.Roi, 'y', result_table.Mean, 'color', result_table.Folder,'subset', ~ismember(result_table.Subindex, [7 9 16 19 32]));
g.stat_summary('type', 'sem', 'geom', 'bar', 'dodge', 0.7, 'width', 0.7, 'setylim', 'false');
g.stat_summary('type', 'sem', 'geom', 'black_errorbar', 'dodge', 0.7, 'width', 0.7, 'setylim', 'false');
g.geom_jitter()
% g.axe_property('ylim', -1.5);
g.geom_hline('yintercept', 0);      
g.set_names('x', 'ROI', 'y', pattern_pref, 'color', 'Volumes')
g.draw();
rotateXLabels(g.facet_axes_handles,45)
g.redraw();

[h p ci test] = ttest(result_table.Mean(~ismember(result_table.Subindex, [7 9 16 19 32])));

% plot per Folder per ROI
figure('Name', 'Folder as X, ROI as Color');
clear g
g=gramm('color', result_table.Roi, 'y', result_table.Mean, 'x', result_table.Folder);%, 'subset', ~ismember(result_table.Subindex, [7 9 16 19 32]));
g.stat_summary('type', 'sem', 'geom', 'bar', 'dodge', 0.7, 'width', 0.7, 'setylim', 'true');
g.stat_summary('type', 'sem', 'geom', 'black_errorbar', 'dodge', 0.7, 'width', 0.7, 'setylim', 'true');
g.geom_hline('yintercept', 0);
g.set_names('x', 'ROI', 'y', pattern_pref, 'color', 'Volumes')
g.draw();
rotateXLabels(g.facet_axes_handles,45)
g.redraw();


% 
unique_rois = unique(result_table.Roi)
for r=1:length(unique_rois)
roi_flag = unique_rois{r};
result_table.Folder;
folder_flag = subdirs{1};
sub_table = result_table(ismember(result_table.Roi,roi_flag) & ismember(result_table.Folder,folder_flag) & ~ismember(result_table.Subindex, [7 9 16 19 32]),:);
disp(unique_rois{r})
[h p ci stats] = ttest(sub_table.Mean)
[p h stats] = signtest(sub_table.Mean)

end


%% interindividual variability

load('../SUBINF.mat');
load('../BEHAVIOR/behavior_32s.mat')

BICdiff = [5.38840874611532,6.27317921089878,11.2505326593606,9.36079257737586,10.9934780435593,14.3216276622246,3.12625835912229,11.3819336544988,-0.765509146220893,7.23795171483454,7.16005628083906,2.93899934919148,8.47550619363631,9.27425924178175,6.92988298697350,17.8555606142873,5.12569229654486,6.29540271235982,8.16168230006275,7.47327042957392,-2.99925204834796,8.68204036535008,19.2712014021815,-1.89170062709582,-13.7185142642742,21.9021284333638,1.04042014789658,20.6801478213325,9.14293236672728,12.7610700986934,16.9334979895538,14.5440473382839];
BICratio = [1.02171361806458,1.01043619825312,1.01086589032870,1.00268766702982,1.00326225457924,1.04921413783793,0.999239454337751,1.00742806191668,0.983085936588745,0.995081187915738,0.990866010193725,0.988620787057029,1.01069852479613,1.01823780369136,1.01959707849731,1.03488166915002,1.02539536448477,0.984106759816097,1.01984041486316,1.00429730012398,0.989655842780746,1.06638602972595,1.07028342070977,0.984056997604496,0.995488875993891,1.05839957944840,1.00565615640565,1.01059589065681,1.00012619399251,1.04832537450915,1.01560815430232,1.03839968897720];
AICratio =[1.06025933713762,1.04396608819362,1.04787364233242,1.04078829751159,1.03888861107482,1.10756636725455,1.02118945098784,1.04399331060398,1.00019084312637,1.02234025618910,1.02074023434271,1.01297794318605,1.04001098941433,1.04831602655925,1.06304544150986,1.08327893870201,1.06256221349564,1.01305089364664,1.06581144029793,1.04001762102841,1.00829619156966,1.12972869994338,1.15918268043742,1.00042940466628,1.01669194356750,1.13448070451070,1.04045201099413,1.05832193741896,1.02737126298718,1.10271772025309,1.05958638928179,1.08739316478333];
accuracy=[0.657894736842105,0.642857142857143,0.704819277108434,0.858108108108108,0.792207792207792,0.732558139534884,0.468992248062016,0.737804878048781,0.487288135593220,0.668539325842697,0.765822784810127,0.670329670329670,0.570754716981132,0.495798319327731,0.725609756097561,0.706896551724138,0.552083333333333,0.833333333333333,0.772727272727273,0.790540540540541,0.402439024390244,0.655555555555556,0.900000000000000,0.458646616541353,0.461832061068702,0.815068493150685,0.694444444444444,0.867647058823529,0.616161616161616,0.675531914893617,0.876811594202899,0.672413793103448];
LLratio=[1.10189294828745,1.08397862780305,1.09481132428220,1.09683811101759,1.08972305094893,1.16131318763443,1.04797494798413,1.09249850110402,1.02743917978173,1.06271223407363,1.07046899572767,1.05224924541254,1.07358917902275,1.07896479655426,1.11418183939700,1.13203597114907,1.10096996516513,1.06894911295705,1.12139517828470,1.09101958358434,1.03461994665286,1.18114776136674,1.24298498660157,1.02509461061111,1.04379402845325,1.20684728076231,1.08593153344389,1.12586212635454,1.06360934186929,1.15121049159585,1.11720610003985,1.13533045939062];
%alphaSS alphaSAS alphaOmega
theta_model10 = [0.336676416524546,0.590130661545602,0.380557665327448,0.348731177104983,0.351106644461408,0.516150112290404,0.301648866638098,0.311374030112382,0.212315255936238,0.476146824208769,0.228454287044518,0.319852044445991,0.545865947570148,0.732262413776149,0.279082321526304,0.305961038239138,0.600881401783745,0.263602622899880,0.342023862408434,0.281457120133082,0.530845145531044,0.396442651475726,0.299006499401216,0.234482049943756,0.467210506997752,0.291932491698799,0.148458870526046,0.503015121380571,0.416790669405538,0.595395532296106,0.318981401225163,0.353089514191332;0.558302575925324,0.498771329836788,0.464736024381292,0.512517319116386,0.671817769456284,0.516299882491126,0.400877494398168,0.629720236937528,0.529934546492456,0.606262360884244,0.519583340321491,0.480793562206713,0.635406235665467,0.459556065593871,0.446519702364212,0.468700011524569,0.360899959193034,0.501768593584325,0.759669267365235,0.471800106131723,0.323751590088788,0.403684280574321,0.515361137984383,0.472258629131040,0.470163860847843,0.571400835399614,0.434544066987590,0.638122751231901,0.673591789172431,0.488291034903063,0.444471164733511,0.577879746080298;0.336595457411062,0.381838533054914,0.193689840364653,0.333102999360056,0.163046620049233,0.203334990437636,0.294441428196942,0.196409795088870,0.544531844136041,0.416934524232321,0.356853268907722,0.386759359221429,0.197418586414446,0.323560311155747,0.237038854724041,0.328387305530553,0.239148808621432,0.238042950963410,0.421627523494648,0.335978069175788,0.320928731668127,0.259267203212482,0.216635761955981,0.346240937191729,0.260117682783762,0.196859790230674,0.134351647628234,0.249748242682043,0.196246020194559,0.394563138660751,0.179363509349895,0.346735295754609];
omega_switch_param = [28.3904744480569,77.9295178054134,25.9524024018404,19.6752797653250,18.9568357605700,50.1963389941233,3.68733113960943,12.1745526141820,10.8522091231714,22.4036813204219,15.5911667776472,25.4648365371455,15.9386670676341,4.44739954192145,17.5862056751255,30.8457754654935,16.6638904388115,15.2938774747848,13.1822655474732,17.5627643237262,13.4177137451546,13.6384023248746,21.4396636771926,52.9560104521603,3.13154187373052,19.9674321848762,20.5618529430040,23.6516259721011,14.8136120770606,62.1708378653872,33.6946379801927,21.1850604499984];
logistic_beta = [1.04065990154762,1.29549301786301,1.61125611206024,1.83536419169127,2.27191401912694,1.27988728502982,0.381096399683473,0.961553771360823,0.294994980397128,1.81945181047670,1.57920285085146,0.869421635379359,0.351640342672457,-0.0569321626624233,1.21722624961733,1.08135038733541,1.13305325570423,1.31880851865143,0.723344055895927,0.768411764975146,0.716046448986835,0.331868498195017,2.43076683085891,0.0247383415693870,0.232773955927136,0.895590299062897,0.747875853480969,2.07746915460048,0.952127170920929,1.66184149538159,1.27130456901198,1.03418255665935];
logistic_intercept = [0.531843687591544,0.969086106703886,0.578888613036515,0.200305767519336,0.601496274673883,0.0257391035085782,0.342423366532897,0.0956361607901974,0.0700026149064100,1.07909436887981,-0.212849362114800,0.264952169466265,0.159230494474563,-0.287924550645258,0.324335387812212,0.409075979327536,0.474827865254489,0.204634262652754,0.638681403430298,0.205002002258145,0.623164458035073,-0.415059843649533,0.734311957276040,1.06890794747516,-0.391140914674907,0.519914415312092,0.578536564362453,0.396017951308186,-0.0907120318329327,1.22123580037886,0.437298191672644,0.559374008934593];
bird_overchance = [0.894423679728351,0.00169694203179160,4.77395900588817e-15,4.77395900588817e-15,2.22218154988241e-09,0.533187523225598,4.77395900588817e-15,4.77395900588817e-15,4.77395900588817e-15,0.998303057968213,6.64857058296775e-12,2.22218154988241e-09,0.999999999998147,0.995228359133784,0.0274509362486690,4.72745430579735e-08,0.598653322465136,4.77395900588817e-15,3.97626934400819e-06,4.77395900588817e-15,0.0565154821409610,2.22218154988241e-09,4.77395900588817e-15,0.139307273172116,0.226685849715492,4.77395900588817e-15,2.29066765555785e-11,0.0565154821409610,0.661465102816583,4.77395900588817e-15,4.77395900588817e-15,0.466812476774401];
decision_param_final = [3.72910632688305,3.81767364759902,3.88358932187506,5.12074973895629,4.24916599137858,3.13695419912679,2.06568632865472,4.07826544826600,1.94961243668884,3.36176708020503,4.76799568639377,2.92598618099691,1.58406692648653,1.45485525052413,5.61098006615110,3.64758260478697,1.89304855417509,5.59363551357275,4.70329411159064,3.97383020899404,1.03992538606588,3.39212435746892,6.20854872645549,1.49423312934062,2.13075468581749,7.15909519739712,5.93449671364470,5.71366158644096,3.02520171985349,3.60846129769880,5.55028693723769,3.46082953930561;10.3939267169737,5.83061826575394,31.3755991864733,8.83558622092199,13.2605139271279,107.197095511410,2.08575021842852,6.46161357044427,88.1650976852642,13.4129771404533,6.01804921009353,9.52353346913444,53.0001686845500,5.08600560224082,16.8770281253376,18.7771374288779,58.8504041457347,10.6158421309682,5.17355246470283,10.5676983395692,12.6023179714780,6.09142565592174,6.85625362270841,2.58335027950861,19.7148157425493,5.69962807118794,6.57239783865833,16.0888703758211,7.19183454744851,33.3217459204687,33.3222957458958,12.1920000539621;-0.102726012005071,-0.218551505505650,-0.0264824971919361,-0.0716711469120591,-0.0812772561158859,0.0199239028864993,0.0843824162186579,0.0129940503728316,-0.129298148459911,-0.0884783654731756,-0.177125641440781,-0.0984598496588799,0.0745590578037376,0.325326420990090,-0.0451416329078657,-0.0500320440893625,0.100796288431283,-0.0681581757408963,-0.163766876722884,-0.0719659315151331,0.0396552147599580,0.317753698084736,-0.114653319414617,-0.0819650455724678,0.334232519699780,-0.187135347216298,-0.284527872035235,-0.0616435116399140,-0.0827679856131752,-0.0319328000846509,-0.0632209134000719,-0.0721481608150101];
omega_bias = [-0.102726012005071;-0.218551505455914;-0.0264824976597079;-0.0716711469278014;-0.0812772561629932;0.0199239028864993;0.0843824162186579;0.0129940503728316;-0.129298148459911;-0.0884783654731756;-0.177125641440781;-0.0984598496588799;0.0745590578037376;0.325326420990090;-0.0451416329078657;-0.0500320440893625;0.100796288431283;-0.0681581757408963;-0.163766876722884;-0.0719659315151331;0.0396552147579972;0.317753698159869;-0.114653319412238;-0.0819650455724678;0.334232519699780;-0.187135347216298;-0.284527872018730;-0.0616435116395054;-0.0827679856219936;-0.0319328000846509;-0.0632209134000719;-0.0721481608150101];
 SSpeRT = [0.0665723793578992	0.260141111714138	0.0939224000212752	-0.0434048137859246	0.464546179803883	0.232707603121385	0.0141765792204288	0.169691165405443	-0.379469255470889	-0.0787740826476723	-0.123142407008495	0.0874775974641636	-0.0540269903078173	-0.00845114590379251	0.0438963729923490	0.251626672109177	0.254831173949986	0.213847585114877	-0.100172942952853	-0.158033881211439	0.303451044951277	-0.0120862111857104	0.0875490963816641	-0.0717008410010082	0.129702811532492	0.323142422241720	0.357587560856130	-0.284058986926416	0.0278760791957541	0.236924136603856	0.377892478870197	0.0242377948959834];
 SASpeRT = [-0.0475197803780578	-0.0286663499978961	0.0712427370776522	0.233323674908676	-0.229021536881617	0.115469110017868	-0.0733305320178345	0.130742636169612	0.334316127074374	0.120628280481106	0.273538537386575	0.270565846742646	0.0463905859125667	0.0731863849006334	0.156685097181104	0.217082360087822	0.00753256573718907	0.153827621038396	0.619004474556133	0.349558680286033	-0.0931440463942141	0.434072557879066	0.195594005314417	0.0654343433902291	-0.122489471162137	0.0975027437380806	0.0537403451519353	0.0919620062550582	0.0344852155582004	-0.175519556071931	0.268940906280853	-0.0641891418698832];
betas_RTcontinuous=[0.211210050337222,-0.000676939457568576,0.00493223710607319;0.221743440692765,0.0606309050173399,0.0804512490754911;0.0167119217065448,0.0317334279716514,1.77000463753819e-05;0.158240927985821,0.0375173497202362,0.137320720172183;-0.197002772023352,-0.185274062354475,0.0788085218914538;0.304934692065470,-0.160084810749858,0.267278560453731;-0.0295449555182098,-0.0205931417658915,-0.00275372121294859;0.0895971267457282,0.147705225238990,-0.0407547228959578;-0.0297777581298096,-0.0185791070978998,0.0198253752599538;0.106190699279331,0.00618563057224792,0.0158816733734114;0.0719267125013781,0.157015008897797,-0.0218818572762106;0.216933097108181,-0.00946326913966549,0.192504473905474;0.0330575585733954,-0.0285957580281828,0.0332326755343255;-0.0350399084479194,-0.0779005786645081,0.00662732241660532;0.216597815644216,-0.00249902884673542,0.135052272793865;0.205859579583596,0.172537253840200,0.137692786693588;0.0214450779505264,0.196080050290503,-0.00851360597568736;0.0635959252231586,-0.0470715338468722,0.0718758569209183;0.388379528783762,-0.0837413912268800,0.356082624013241;0.112222933401684,-0.0336820835780319,0.157794642869749;-0.0640696170448357,0.238893072635759,-0.103292677910653;-0.0457432513914678,0.304666369380244,-0.0986164445099189;0.113820321582706,0.0403566721165929,0.0627621582558932;-0.121119939032767,0.00329749668188425,-0.0259533820354830;-0.0742021802990417,0.0251548884082019,-0.0684170410775748;0.266117657636802,0.148606009839076,0.00576605262318916;0.109579581677203,0.172903805005664,0.0427365508584393;-0.0322543896390867,-0.145486277918979,-0.0207036756457815;0.196316909190020,-0.0135360228030747,0.0328368904642234;0.00571762460408728,0.0983836836603955,-0.0922183680372789;0.444040597847048,-0.313065559088333,0.472184449478398;0.0952627209567002,0.0449127807071941,-0.0314751758791953];
betas_RTcontinuous=[0.154237096918122,0.0184049114551788,-0.00511854801448224;0.226669402004017,0.0606270786011910,0.0836798152077415;0.0322669526229096,0.00441766376265006,0.00274631267448031;0.162668418115809,0.0400108758470460,0.129577334591760;-0.189694893581556,-0.192906310574629,0.0852940854007006;0.327188180332656,-0.161879617782972,0.268384545168319;-0.0250623893468066,-0.0230407229872077,-0.00172831212382969;0.0717327773421372,0.153789477086742,-0.0616865225534630;-0.0253359422662409,-0.0207271366601921,0.0230971660049425;0.0873841019475386,0.00882108349883217,0.00396868265876173;0.0974018030684038,0.150131606947445,-0.00382401773407653;0.218925558814426,-0.0239136299128713,0.196333597007024;0.0289021276485441,-0.0305243143445508,0.0424059059316863;-0.0510006654727838,-0.0960991687927418,0.00155508569332235;0.213752854965649,-0.00349562167911659,0.136718752882078;0.201441101506243,0.172137107099833,0.139706154063141;0.0210505475939096,0.198487772500622,-0.0165509537536640;0.0697821099190343,-0.0521671978707344,0.0715278259926999;0.408408027937914,-0.0912708703658112,0.361558454993311;0.111645605342640,-0.0331031120421843,0.157578620262377;-0.0611243270744349,0.232682924836318,-0.102711219748407;-0.0462595801539426,0.309591478964023,-0.101683399780303;0.114540293149510,0.0405411494001310,0.0623535946558962;-0.124895127070167,0.00628932784133539,-0.0277043539184426;-0.0894847351858366,0.0291226422516110,-0.0731344911621374;0.266606195868500,0.146607251208857,0.00638378140656674;0.0980293737193753,0.156394500313715,0.0546306130377419;-0.0302454583062853,-0.149353327607499,-0.0174595948881625;0.197006780221999,-0.00985150877064656,0.0320818394497600;0.0121421375179128,0.107523566702584,-0.0918826345761940;0.474464199076614,-0.315255589990448,0.480819945329377;0.0735976024879821,0.100540728573495,-0.0575743588104787];

SASpeRT=betas_RTcontinuous(:,3);
SSpeRT=betas_RTcontinuous(:,2);
OmegaRT=betas_RTcontinuous(:,1);


cbias = [1.16326530612245,1.54761904761905,1.14285714285714,1.05714285714286,1.23529411764706,0.933333333333333,1.08695652173913,1.02439024390244,1,1.46153846153846,0.972222222222222,1.08695652173913,1.05555555555556,0.708333333333333,0.957446808510639,1.11111111111111,0.965517241379311,1.05714285714286,1.19512195121951,1,1.06849315068493,0.642857142857143,1.12500000000000,1.67796610169492,0.662500000000000,1.37500000000000,1.47368421052632,1,0.940000000000000,1.20754716981132,1.05405405405405,1.29268292682927];
% get Omega bias
% load('/project/3017049.01/SASSS_fMRI1/BEHAVIOR/modeling_seq_final/o_MBtype2_wOM2_bDEC1_max_nobound_e_aSASSSSAS1_aOMIntInf1_nobound_13-Oct-2019_1/fitted_model.mat','muX', 'phiFitted', 'thetaFitted')
load('/project/3017049.01/SASSS_fMRI1/BEHAVIOR/modeling_seq_final/o_MBtype2_wOM2_bDEC1_nobound_e_aSASSSSAS1_aOMIntInf1_prior1_28-Jun-2021_1/fitted_model.mat');

omega_ind = 49;
for s=1:length(muX)
    mean_sigomega(s,1) = mean(VBA_sigmoid(muX{s}(omega_ind,:), 'slope', phiFitted(s,2), 'center', phiFitted(s,3)));
    mean_omega(s,1)=mean(muX{s}(omega_ind,:));
end
%
behvar = [BICratio' accuracy' global_controlACC cbias' phiFitted thetaFitted mean_omega mean_sigomega SSpeRT SASpeRT OmegaRT];
behvar = behvar(subset_subj,:);
% behlab = {'BICratio' 'accuracy' 'controlACC' 'cBias', 'InvTemp' 'InvTempOm' 'BiasOm' 'Alpha' 'AlphaOm' 'Mean_omega' 'mean_sigomega' 'SSpeRT' 'SASpeRT'};
behlab = {'BICratio' 'accuracy' 'controlACC' 'cBias', 'InvTemp' 'InvTempOm' 'BiasOm' 'Alpha' 'AlphaOm' 'Inference' 'Mean_omega' 'mean_sigomega' 'SSpeRT' 'SASpeRT','OmegaRT'};

behlab = repmat(behlab,length(subset_subj),1);
% behvar=mean_sigomega;
% behlab=repmat({'mean_sigomega'},length(subset_subj),1);
unique_rois = unique(result_table.Roi)
for r=1:length(unique_rois)
    roi_flag = unique_rois{r};
    sub_table = result_table(ismember(result_table.Roi,roi_flag) & ismember(result_table.Subindex,subset_subj),:);
    unique_folders = unique(result_table.Folder);
    for f=1:length(unique_folders)
         figure('Name', [unique_folders{f} ' and ' unique_rois{r}])
         clear g
         y=repmat(sub_table.Median(ismember(sub_table.Folder, unique_folders{f})),1,size(behvar,2));
         x=behvar;
         col=behlab;
         
         g=gramm('x',x(:),'y',y(:));
         g.facet_wrap(col, 'ncol',4, 'scale', 'independent');
         g.stat_glm();
         g.geom_point();
         g.draw();
         drawnow
         corrmat=[sub_table.Median(ismember(sub_table.Folder, unique_folders{f})) behvar];
         disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
         disp([unique_folders{f} ' and ' unique_rois{r}])
         [corr_r p] = corr(corrmat)%,'type', 'spearman')
         disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')

    end
end
% [corr_r p] = corr(corrmat(:, [1 end-3 end-7]))

% orr(corrmat(:,[1 10]);% [1 end-3 end-7]))
%% colors
CC.omegaPE = [20 55 90]/100;
CC.ssPE = [30 80 30]/100;
CC.sasPE = [85 80 20]/100;
CC.omega = [80 35 80]/100;
CC.RT = [90 30 30]/100;
CC.main_effect = [45 45 45]/100;
CC.omegaPE = [20 55 90]/100;
CC.ssPE = [30 80 30]/100;
CC.sasPE = [85 80 20]/100;
CC.omega = [80 35 80]/100;
CC.sasminssPE = [90 56 10]/100;
CC.RT = [90 30 30]/100;
CC.main_effect = [45 45 45]/100;

%% custom plots

%%%% PCC OMPE / Slowing
sub_table = result_table(ismember(result_table.Roi,'InvOmPE_pCC_001') & ismember(result_table.Subindex,subset_subj),:);
x= repmat(sub_table.Mean, 1, 2)
y=behvar(:, [strmatch('SASpeRT', behlab(1,:)) strmatch('SSpeRT', behlab(1,:))]);
color=repmat([1:2],32,1);
color_str={'SASpeRT', 'SSpeRT'};
color=color_str(color);

color_map = [CC.sasPE; CC.ssPE];

figure('Position', [  674   852   85    85])

g=gramm('x', x(:), 'y', y(:), 'color', color(:))
g.geom_point()
g.set_color_options('map', color_map);
g.set_order_options('color', 0, 'x', 0);
g.set_text_options('base_size', 4, 'font', 'Myriad Pro')
g.set_point_options('base_size', 3);
g.stat_glm()
g.no_legend();
g.set_names('y', 'PE-RT slowing (a.u)', 'x', 'pCC OmegaPE')
g.draw()

corrmat=[x(:,1) y];
% lillietest(corrmat(:,3))

[r p] = corr(corrmat);%, 'type', 'spearman')



%%%% PCC OMPE / Sigomega
sub_table = result_table(ismember(result_table.Roi,'InvOmPE_pCC_001') & ismember(result_table.Subindex,subset_subj),:);
x= repmat(sub_table.Mean, 1, 1)
y=behvar(:, [strmatch('BiasOm', behlab(1,:))]);
color=repmat([1],32,1);
color_str={'BiasOm'};
color=color_str(color);

color_map = [CC.omega;];

figure('Position', [  674   852   85    85])

g=gramm('x', x(:), 'y', y(:), 'color', color(:))
g.geom_point()
g.set_color_options('map', color_map);
g.set_order_options('color', 0, 'x', 0);
g.set_text_options('base_size', 4, 'font', 'Myriad Pro')
g.set_point_options('base_size', 3);
g.stat_glm()
g.no_legend();
g.set_names('y', 'BiasOm (a.u)', 'x', 'pCC OmegaPE')
g.draw()

%%%% PCC OMPE / BiasOm
sub_table = result_table(ismember(result_table.Roi,'InvOmPE_pCC_001') & ismember(result_table.Subindex,subset_subj),:);
x= repmat(sub_table.Mean, 1, 1)
y=behvar(:, [strmatch('mean_sigomega', behlab(1,:))]);
color=repmat([1],32,1);
color_str={'SigOmega'};
color=color_str(color);

color_map = [CC.omega;];

figure('Position', [  674   852   85    85])

g=gramm('x', x(:), 'y', y(:), 'color', color(:))
g.geom_point()
g.set_color_options('map', color_map);
g.set_order_options('color', 0, 'x', 0);
g.set_text_options('base_size', 4, 'font', 'Myriad Pro')
g.set_point_options('base_size', 3);
g.set_names('y', 'SigOm (a.u)', 'x', 'pCC OmegaPE')
g.stat_glm()
g.no_legend();
g.set_names('y', 'SigOmega (a.u)', 'x', 'pCC OmegaPE')
g.draw()


%% interindividual variability PERSONALITY

load('../SUBINF.mat');
load('../BEHAVIOR/behavior_32s.mat')
load('../scored_questionnaires.mat')

%
behvar = fmri_Q;
behvar = behvar(subset_subj,:);
behlab = fullheader;
behlab = repmat(behlab,length(subset_subj),1);
unique_rois = unique(result_table.Roi)
for r=1:length(unique_rois)
    roi_flag = unique_rois{r};
    sub_table = result_table(ismember(result_table.Roi,roi_flag) & ismember(result_table.Subindex,subset_subj),:);
    unique_folders = unique(result_table.Folder);
    for f=1:length(unique_folders)
         figure('Name', [unique_folders{f} ' and ' unique_rois{r}])
         clear g
         y=repmat(sub_table.Mean(ismember(sub_table.Folder, unique_folders{f})),1,size(behvar,2));
         x=behvar;
         col=behlab;
         g=gramm('x',x(:),'y',y(:));
         g.facet_wrap(col, 'ncol',4, 'scale', 'independent');
         g.stat_glm();
         g.geom_point();
         g.set_order_options('x', 0,'column', 0)
         g.draw();
         drawnow
         corrmat=[sub_table.Mean(ismember(sub_table.Folder, unique_folders{f})) behvar];
         disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')
         disp([unique_folders{f} ' and ' unique_rois{r}])
         [corr_r p] = corr(corrmat,'type', 'spearman', 'rows', 'pairwise')
         disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%')

    end
end

%%%% PCC OMPE / Slowing
sub_table = result_table(ismember(result_table.Roi,'InvOmPE_pCC_001') & ismember(result_table.Subindex,subset_subj),:);
x= repmat(sub_table.Mean, 1, 2)
y=behvar(:, [strmatch('iLOC', behlab(1,:)) strmatch('extLOC', behlab(1,:))]);
color=repmat([1:2],32,1);
color_str={'iLoC', 'eLoC'};
color=color_str(color);

color_map = [CC.sasPE; CC.ssPE];
figure('Position', [  674   852   85    85])
g=gramm('x', x(:), 'y', y(:), 'color', color(:))
g.geom_point()
g.set_color_options('map', color_map);
g.set_order_options('color', 0, 'x', 0);
g.set_text_options('base_size', 4, 'font', 'Myriad Pro')
g.set_point_options('base_size', 3);
g.set_order_options('x', 0,'color', 0)
g.stat_glm()
% g.no_legend();
g.set_names('y', 'PE-RT slowing (a.u)', 'x', 'pCC OmegaPE')
g.draw()


[r p] = corr([SSpeRT' SASpeRT' y],'type', 'spearman', 'rows', 'pairwise')
