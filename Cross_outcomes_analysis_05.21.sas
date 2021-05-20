/*Name: Shalmali Bane*/
/*Date started: April 17, 2020*/
/*Date last modified: May 5, 2021*/
/*File used to run: OSHPD Stillbirth, preterm birth, small for gestational age cross outcomes analysis */
/*Description: This script creates an analytic dataset to conduct a cross outcomes analysis between*/
				/*stillbirth, PTB, and SGA*/
/*File used to run: OSHPD cros outcomes analysis */
/*Final dataset created: 05.05.2021*/ 

libname ssb 'D:\UserData\sbane\3. thesis';
libname OSHPD 'D:\Projects\Carmichael-Lee-Data\OSHPD';
%INC "D:\UserData\sbane\3. thesis\formats.sas";

/*Sections:*/
/*1. Read in and clean Birth Records*/
/*1a. Read in files for 1997-2011, keeping only birth records*/
/*1b. combine dataset years*/
/*1c. fix the parity variable*/
/*1d. Output SGA 10th percentile cutoffs*/
/*1e. Define unlinked births*/
/*1f. Exclude women who had missing parity or parity > 15 at first birth in california or women who had just one birth, unlinked births*/
/*1g. Include only singletons, gestational age non missing 20-45 weeks, birthweight non missing 250-9000g*/
/*1h. Include only birth pairs in cohort, i.e. exclude births without a subsequent included birth*/
/*1i. Create permanent clean dataset*/

/*2. Defining Outcome Variables*/
/*2a. Preterm birth*/
/*2b. SGA*/
/*2c. Causes of fetal death*/

/*3. Creating dataset with 1 row per birth pair*/
/*3a. Create one row with all information for consecutive pairs*/
/*3b. Drop observations that did not have a subsequent birth*/
/*3c. Confirm that only subsequent birth pairs are retained*/
/*3d. Create permanent clean datasets*/
/*3e. Create sensitivity cohort with just parity 1 and 2*/

/*4. Table 1 Maternal Characteristics */
/*4a. Read in maternal characteristics*/
/*4b. Define new levels of maternal characteristics for race, education, insurance, age at delivery*/
/*4c. Define formats for maternal characteristics*/
/*4d. Create deduped dataset with one row per unique mother*/
/*4e. Calculate descriptive statistics for maternal characteristics*/
/*4f. Unlinked births demographics*/

/*5. Main Analysis*/
/*5a. Frequency*/
/*5b. Unadjusted risk*/
/*5c. Adjusted risk*/  
/*5d. Stratified Sensitivities*/

/*6. Sensitivity Analyses*/
/*6a. Unlinked births*/
/*6b. First and second births only cohort*/

/*7. IPCW analysis*/
/*7a. Recreate population with women who just had first births and women who had births 1 and 2*/
/*7b. Create a variable for censored status and join datasets (sensitivity cohort+ IPCW population) together*/
/*7c. Calculate fitted probability of censoring - first get propensity score, then take inverse*marginal probability*/
/*7d. Assess positivity assumption using log odds plot*/
/*7e. Re run analyses with IPCW*/

/*1. Read in and clean Birth Records*/
/*1a. Read in files for 1997-2011, keeping only birth records*/
%macro readall;
%do x=1997 %to 2011;
data a&x. (keep = _brthid _losM caesar caesar05 _brthidhst typebth bthorder bthdate estgest
      gest probl_1 paymsold prevlbl prevlbd _year mage admdateM  disdateM disstat95M
      parity mrace msporig racem_c1 diagM00-diagM24 PROCM00-PROCM20 precare meduc bthwght
      meduc06 _twinwght _linkedb fdeath icd10d icd10f icd9d icd9f _twinb _twinm _twini _losM probl_2 ceb sex bthresmb bthresmb06);
      set oshpd.sc_lb&x. (where=(_input='B'));
run;
%end;
%mend;
%readall;

/*1b. combine dataset years*/
data ssb.initial;
	set a1997-a2011;
	if _twinwght ^=0;
run;

/*1c. fix the parity variable*/
libname par "D:\Projects\Carmichael-Lee-Data\OSHPD\Parity";

/*Join current cohort with file with correct parities created by Peggy*/
proc sql; 
create table all2 as
select A.*, newpar, fceb 
from ssb.initial A
left join par.parity B
on A._brthid=b._brthid; 

/*proc freq data=all2; table parity*newpar/ norow nocol nopercent; run; */

proc sort data = all2 out = check nodupkey; by _brthidhst; run; 

/*Create flags for later exclusions based on parity*/
data all2;
	set all2;
	if '01' <= fceb <= '15' then par_var = '1. keep';
	if fceb in ('00','99','') then par_var = '2. miss';
	if '15' < fceb < '99' then par_var = '3. gt15';
run;

/*proc freq data=all2; table fceb*par_var/ norow nocol nopercent; run;*/

/*1d. Output SGA 10th percentil cutoffs*/
/*Define gestational age*/
data all3; set all2;
if 20<=estgest<=45 then gestage=estgest*1;
else if 20*7<=gest<=45*7+6 then gestage=int(gest/7)*1;
label gestage="Gestational age" gest="Length of gestation in days";
gestage1 = floor(gestage); 
run;

/*proc freq data=all3; tables gestage estgest*gest*gestage/list missing; run;*/

/*LGA SGA information;*/
PROC MEANS DATA=all3 (WHERE=(TYPEBTH="1" AND SEX IN("1" "2") AND 200<=BTHWGHT<=9000)) N MEAN P10 P90; 
VAR BTHWGHT; CLASS gestage SEX; ODS OUTPUT SUMMARY=ssb.birthwt_percentiles; RUN;

PROC SQL;
 CREATE TABLE all3b AS
 SELECT A.*, BTHWGHT_P10, BTHWGHT_P90,
        CASE WHEN ^(200<=A.BTHWGHT<=9000) OR ^(20<=A.gestage<=45) OR A.TYPEBTH^="1" OR A.SEX^IN("1" "2") THEN . 
		     WHEN A.BTHWGHT<=BTHWGHT_P10 THEN 1
			 ELSE 0
		END AS SGA
 FROM all3 A
 LEFT JOIN ssb.birthwt_percentiles B
 ON A.gestage=B.gestage AND A.SEX=B.SEX;

/*proc freq data=all3b; table sga; run;*/

/*1e. Define unlinked births*/
data all3c;
set all3b;
if _linkedb in ('Y','M') then linked = 1; else linked = 0;
run;

/*proc freq data=all3c; table linked; run;*/
/*proc freq data=all3c; table (_year fdeath)*linked/ nopercent nocol; run;*/

/*1f. Exclude women who had missing parity or parity > 15 at first birth in california or women who had just one birth, unlinked births*/
data all4;
      set all3c;
      birth = 1;
run;
 
proc sort data = all4; by _brthidhst; run;
 
/*get the total number of births that a woman has in the study period*/
proc summary data = all4;
      var birth;
      by _brthidhst;
      output out = n_birth (drop = _freq_ _type_) sum = n_birth;
run;
 
/*add the number of births and first birth variables to the cohort*/
proc sort data = all4; by _brthidhst; run;
proc sort data = n_birth; by _brthidhst; run;
 
data all5;
      merge all4 (in = a) n_birth (in = b);
      by _brthidhst;
      if a and b;
run;

/*Start of flow chart N = 8036764*/
/*Unique mothers n = */
proc sort data = all5 out = check nodupkey; by _brthidhst; run;
 
/*create seperate datasets including births that fall into each exclusion criteria*/
data all6 one_birth miss gt15 unlinked;
      set all5;
      if n_birth = 1 then output one_birth; /*woman only had one birth*/
	  if par_var = '2. miss' then output miss;
	  if par_var = '3. gt15' then output gt15;
	  if linked = 0 then output unlinked;
	  if n_birth ne 1 and par_var = '1. keep' and linked = 1 then output all6;
run;

proc sort data = all6 out = check nodupkey; by _brthidhst; run; /*N = 3876286 to 1,636,732*/
proc sort data = miss out = check nodupkey; by _brthidhst; run;
proc sort data = gt15 out = check nodupkey; by _brthidhst; run;
proc sort data = one_birth out = check nodupkey; by _brthidhst; run; 
proc sort data = unlinked out = check nodupkey; by _brthidhst; run; 

/*Combination of all variables dropped*/
data drop_all; set one_birth miss gt15 unlinked; run;
proc sort data = drop_all out = check nodupkey; by _brthidhst; run; 

/* Output a dataset for later IPCW  - Apply parity variable and linkage exclusions to the cohort with just one birth */
data ssb.ipcw1 drop;
set one_birth;
	  if par_var = '2. miss' then output drop;
	  if par_var = '3. gt15' then output drop;
	  if linked = 0 then output drop;
	  if par_var = '1. keep' and linked = 1 then output ssb.ipcw1;
run;

/* Output a dataset for later linked vs. unlinked analysis - Apply parity variable and linkage exclusions to the cohort with just one birth */
data ssb.linkage drop;
set all5;
	  if par_var = '2. miss' then output drop;
	  if par_var = '3. gt15' then output drop;
	  else output ssb.linkage;
run;

/*1g. Include only singletons, gestational age non missing 20-45 weeks, birthweight non missing 250-9000g*/
/*only keep births with gestational age 20-45 weeks, excluding missing*/
/*only keep births with birth weight 250-9000g, excluding missing*/
/*only keep births with infant sex, excluding missing*/
/*define multiple births and include keep only singleton*/
data all7;
	set all6;
	if _twinB='Y' OR _twinM='Y' OR _twinI='Y' OR Typebth =9 THEN twin=1; else twin = 0;
	if gestage = . then gest_miss = 1; else gest_miss = 0;
	if bthwght = . then miss_bweight = 1; else miss_bweight = 0;
	if 0 <= bthwght < 250 then bw_lt250 = 1; else bw_lt250 = 0;
	if 9000 <= bthwght then bw_gt9000 = 1; else bw_gt9000 = 0;
	if sex in (1 2) then sex_miss = 0; else sex_miss = 1;
run;

proc freq data = all7;
	table twin gest_miss miss_bweight bw_lt250 bw_gt9000 sex_miss;
run;

data all8 drop;
	set all7;
	if twin = 0 and gest_miss = 0 and miss_bweight = 0 and bw_lt250 = 0 
	and bw_gt9000 = 0 and sex_miss = 0 then output all8;
	else output drop;
run;

proc sort data = all8 out = check nodupkey; by _brthidhst; run; /*N = 3,659,089, unique: 1,629,856*/

/*1h. Include only birth pairs in cohort, i.e. exclude births without a subsequent included birth*/
/*check to see if there were previous or subsequent births*/
proc sort data = all8; by _brthidhst newpar; run;

data all9;
	set all8;
	by _brthidhst newpar;
	prev_parity = lag(newpar);
	if first._brthidhst then prev_parity = .;
run;

proc sort data = all9; by _brthidhst descending newpar; run;

data all10;
	set all9;
	by _brthidhst descending newpar;
	next_parity = lag(newpar);
	if first._brthidhst then next_parity = .;
run;

/*proc freq data=all10; tables next_parity*newpar prev_parity*newpar/ norow nocol nopercent; run;*/

data all11;
	set all10;
	diff_next = next_parity - newpar;
	diff_prev = newpar - prev_parity;
run;

data all12 drop;
	set all11;
	if diff_next = 1 or diff_prev = 1 then output all12;
	else output drop;
run;
/*dropped: 169618*/

proc sort data = all12 out = check nodupkey; by _brthidhst; run;
/*N = 3489471; unique = 1,494,374*/

proc sort data = all12; by _brthidhst; run;

proc summary data = all12;
	var birth;
	by _brthidhst;
	output out = new_n_birth (drop = _freq_ _type_) sum = n_birth2;
run;

/*proc freq data = new_n_birth; table n_birth2; run;*/

/*proc freq data=all12; table newpar; run;*/

/*1i. Create permanent clean dataset*/
data ssb.cohort; set all12; run;

/*2. Defining Outcome Variables*/
/*2a. Preterm birth*/
data cohort2;
set ssb.cohort;
if gestage > 36 then ptb = 0;
else if gestage <= 36 then ptb =1;
run;

/*2b. SGA and Stillbirth*/
proc freq data=cohort2; table pregout*SGA/norow nocol; format pregout $pregout.; run;
proc freq data=cohort2; tables SGA fdeath ptb/ norow nocol; format SGA bin. fdeath $bin. ptb bin.; run;

/*2c. Causes of Stillbirth*/
data cohort3;
	set cohort2;
	if icd10d="P95"   then fdcat=0;
	else  if icd10d in: ('P025','P026','P024','Q270','P500','P501') then fdcat=1;
	else  if icd10d in: ("P021","P022","P023","P020","P028","P029") then fdcat=2;
	else  if icd10d in: ("P072","P011","P010","P073","P038","P012","P240","P031","P030","P039","P550","P017","P014") then fdcat=3;
	else  if icd10d in: ("P027","P351","P002","P369","P399","P360","B343","A502","P398","P239","P365","P359","P352","P371","R75") then fdcat=4;
	else  if icd10d in: ("Q899","Q897","Q913","Q000","Q909","Q999","Q249","Q969","Q917","Q793","Q039","Q927","Q602","Q898","Q798","P298","Q042","Q234","Q248","Q606","Q079","Q928","Q790",
			"Q792","Q771","Q780","Q225","Q049","Q043","Q031","Q639","Q019","Q929","Q614","Q601","Q02","Q890","Q872","Q799","Q960","Q789","Q613","Q611","Q759","Q226","Q213","Q251","Q764","Q743",
			"Q730","Q713","Q439","Q432","Q410","Q348","Q283","Q678","Q253","Q252","Q250","Q605","Q749","Q243","Q648","Q559","Q203","Q201","Q070","Q069","Q231","Q212","Q211","Q018","Q012","Q010",
			"Q620","Q992","Q685","Q668","Q643","Q210","Q189","Q068","Q059","Q048","Q011","D821","Q998","Q938","Q911","Q878","Q870","Q772") then fdcat=5;
	else  if icd10d in: ("P701","P700","P008","P018","P504","P001","P003","P009","P004","P048") then fdcat=6;
	else  if icd10d =: "P000" then fdcat=7;	
	else fdcat = 8;
run;

/*proc freq data=cohort3; table fdcat*fdeath/ nopercent norow; format fdcat fdcat.; run;*/
/*proc freq data=cohort3; table (icd10d icd9d icd9f)*_year/ norow nocol nopercent; run;*/

/*Create permanent dataset*/
data ssb.cohort2; set cohort3; run;

/*3. Creating dataset with 1 row per birth pair*/
/*3a. Create one row with all information for consecutive pairs*/
data cohortlong1;
      set ssb.cohort2;
run;
 
proc sort data = cohortlong1; by _brthidhst descending newpar; run;
 
data cohortlong2;
      set cohortlong1;
      by _brthidhst descending newpar;
      next_parity = lag(newpar);
      next_sga = lag(sga);
      next_fdeath = lag(fdeath);
      next_ptb = lag(ptb);
      next_brthid = lag(_brthid);
	  next_gestage = lag(gestage);
      if first._brthidhst then do;
            next_parity = .;
            next_sga = .;
            next_fdeath = .;
            next_ptb = .;
            next_brthid = .;
			next_gestage = .;
      end;
run;
 
/*3b. Drop observations that did not have a subsequent birth*/
data cohortlong3 drop;
      set cohortlong2;
      if next_parity - newpar = 1 then output cohortlong3;
      else output drop;
run;
 
/*3c.Confirm that only subsequent birth pairs are retained*/
/*proc freq data=cohortlong3; tables next_parity*newpar / norow nocol nopercent; run;*/
 
/*quick check of same outcomes across subsequent births*/
/*proc freq data=cohortlong3;*/
/*      tables next_sga*sga next_fdeath*fdeath next_ptb*ptb next_gestage*gestage/riskdiff norow nopercent;*/
/*run;*/
/* */
/*look at sga and ptb in birth after a stillbirth*/
/*proc freq data=cohortlong3;*/
/*      tables fdeath*next_sga fdeath*next_ptb/riskdiff norow nopercent;*/
/*run;*/
/* */
/*look at stillbirth and ptb in birth after sga*/
/*proc freq data=cohortlong3;*/
/*      tables sga*next_fdeath sga*next_ptb/riskdiff norow nopercent;*/
/*run;*/
 
/*look at stillbirth and sga in birth after ptb*/
/*proc freq data=cohortlong3;*/
/*      tables ptb*next_fdeath ptb*next_sga/riskdiff norow nopercent;*/
/*run;*/

/*3d. Create permanent clean datasets*/
data ssb.cohort3; set cohortlong3; run;

/*3e. Create sensitivity cohort with just parity 1 and 2*/
data ssb.cohortsens; set ssb.cohort3; if newpar = 1; run;

/*proc freq data=ssb.cohortsens; table newpar next_parity; run;*/
proc sort data = ssb.cohortsens out = check nodupkey; by _brthidhst; run;

/*4. Table 1 Maternal Characteristics at first birth*/
/*4a. Read in maternal characteristics*/
data mat_cat1;
	set ssb.cohort3;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\HYPERTENSION.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\DIABETES.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MRACE7C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MEDUC6C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\INSURANCE.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\USBORN.sas";
run;

proc contents data=mat_cat1; run;

/*4b. Define new levels of maternal characteristics for race, education, insurance, age at delivery*/
data mat_cat2;
set mat_cat1;
select (mrace7c);
	when ('1') mrace5c=1;  
	when ('2') mrace5c=2; 
	when ('5') mrace5c=3;  
	when ('3') mrace5c=4; 
	when ('4') mrace5c=4;
	when ('6') mrace5c=5; 
	when ('7') mrace5c=5;
	when (.) mrace5c=5;
end;
select (delpayer);
	when ('1') delpayer3c = 2;
	when ('2') delpayer3c = 1;
	when ('3') delpayer3c = 3;
	when ('4') delpayer3c = 3;
	when (.) delpayer3c = 3;
end;
select (meduc6c);
	when ('1') meduc4c = 1;
	when ('2') meduc4c = 1;
	when ('3') meduc4c = 2;
	when ('4') meduc4c = 3;
	when ('5') meduc4c = 3;
	when (.) meduc4c = 4;
end;

select (usborn);
	when ('.') usborn3c = 0;
	when ('0') usborn3c = 1;
	when ('1') usborn3c = 2;
end;

if mage=. then mage_cat=5;
else if mage < 20 then mage_cat = 1;
else if 30 > mage >= 20 then mage_cat = 2;
else if 40 > mage >= 30 then mage_cat = 3;
else if mage >= 40 then mage_cat = 4;

if newpar >= 5 then parcat = 5;
else parcat = newpar;

if gestage <= 30 then gest_cat = 1;
else if 30 < gestage <= 36 then gest_cat = 2;
else gest_cat = 3;

if fdeath = 0 and sga = 0 and ptb=0 then complication = 0; 
else complication = 1;
run; 

/*proc freq data= matcat_2; */
/*tables mrace7c*mrace5c delpayer*delpayer3c meduc6c*meduc4c mage*mage_cat prehyp predia gestage1*gest_cat newpar*parcat*/
/*usborn*usborn3c / nopercent nocol norow list missing; */
/*run; */

/*4c. Create permanent datasets - all + deduped dataset with one row per unique mother*/
/*All births*/
data ssb.cohort4_all; set mat_cat2; run;

/*One row per mother*/
proc sort data = mat_cat2; by _brthidhst newpar; run; 

data ssb.cohort4_mat; set mat_cat2; by _brthidhst newpar; if first._brthidhst; run;

/*4d. Calculate descriptive statistics for maternal characteristics*/
proc freq data=ssb.cohort4_all; table ptb sga fdeath/ norow nopercent; run;
proc freq data=ssb.cohort4_mat; table ptb sga fdeath/ norow nopercent; run;

/*Mother-level statistics*/
/*All population*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohort4_mat; 
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn / list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp. usborn usborn.;
run;

/*No complications*/
proc freq data=ssb.cohort4_mat;
where complication = 0;
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn/ list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia.  prehyp hyp.
  SGA bin. fdeath $bin. ptb bin. USBORN usborn.;
run;

/*Outcomes of interest*/
/*Code to make easiest export to tables*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis.results.xls"
options(autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohort4_mat; 
where fdeath="1";
table (mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn)*fdeath / norow nocol list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp. 
 fdeath $bin. usborn usborn.;
run;

proc freq data=ssb.cohort4_mat; 
where ptb = 1;
table (mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn)*ptb /norow nocol list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp. ptb bin. 
usborn usborn.;
run;

proc freq data=ssb.cohort4_mat; 
where sga=1;
table (mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn)*sga / norow nocol list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp. sga bin.  usborn usborn.;
run;

ods tagsets.excelxp close;

proc means data=ssb.cohort4_mat mean std median Q1 Q3; var mage; run;
proc means data=ssb.cohort4_mat mean std median Q1 Q3; var mage; class sga; run;
proc means data=ssb.cohort4_mat mean std median Q1 Q3; var mage; class ptb; run;
proc means data=ssb.cohort4_mat mean std median Q1 Q3; var mage; class complication; run;
proc means data=ssb.cohort4_mat mean std median Q1 Q3; var mage; class fdeath; run;

/*Birth Level characterisitcs*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(autofit_height="yes"
suppress_bylines="yes") style=normal;

/*All population*/
proc freq data=ssb.cohort4_all; 
table parcat gest_cat;
format parcat parcat. gest_cat gest_cat. SGA bin. fdeath $bin. ptb bin. ;
run;

/*No Complication*/
proc freq data=ssb.cohort4_all; 
where complication=0;
table  parcat gest_cat;
format parcat parcat. gest_cat gest_cat. SGA bin. fdeath $bin. ptb bin. ;
run;

/*Outcomes*/
proc freq data=ssb.cohort4_all; 
where fdeath='1';
table (parcat gest_cat)*(fdeath) /  list missing;
format parcat parcat. gest_cat gest_cat. SGA bin. fdeath $bin. ptb bin. ;
run;

proc freq data=ssb.cohort4_all; 
where ptb = 1;
table (parcat gest_cat)*(ptb) / list missing;
format parcat parcat. gest_cat gest_cat. SGA bin. fdeath $bin. ptb bin. ;
run;

proc freq data=ssb.cohort4_all; 
where sga=1;
table (parcat gest_cat)*(sga) / list missing;
format parcat parcat. gest_cat gest_cat. SGA bin. fdeath $bin. ptb bin. ;
run;

ods tagsets.excelxp close;

/*Causes of Still birth*/
/*Restrict to 1999 onwards since 1997-1998 the use of th ICD-10 codes is uneven*/
data sb_causes; set ssb.cohort4_all; if 1998 < _year; run;

proc freq data= sb_causes; table _year; run; 

proc freq data = sb_causes; where fdcat = 8 and fdeath = "1"; table icd10d; run;

proc freq data=sb_causes; where fdeath = "1"; table fdcat; format fdcat fdcat.; run;

/*5. Main Analysis*/
/*Create numerical variable for stillbirth and combined variable for all outcomes*/
data ssb.cohort4_all;
set ssb.cohort4_all;
fdeath1 = fdeath + 0;
next_fdeath1 = next_fdeath + 0;
if next_sga = 1 or next_fdeath = 1 or next_ptb then next_any = 1; else next_any = 0;
if gestage1 < 37 then sb_early = 1; else sb_early = 0;
if gestage >= 37 then sb_late = 1; else sb_late =0;
if gestage <33 then vpreterm = 1; else vpreterm = 0;

if next_gestage >= 37 and next_fdeath1 = 1 then next_sb_late = 2; 
else if next_gestage < 37 and next_fdeath1 = 1 then next_sb_late = 1;
else next_sb_late = 0;
 
if next_sb_late = 1 then next_sb_late1 = 0;
else if next_sb_late = 2 then next_sb_late1 = 1;
else next_sb_late1 = next_sb_late;
if next_sb_late = 2 then next_sb_early1 = 0;
else next_sb_early1 = next_sb_late;
run;

/*proc freq data=ssb.cohort4_all; */
/*table gestage1*(sb_early sb_late vpreterm)/ norow nocol nopercent; */
/*run;*/

/*proc freq data=ssb.cohort4_all;  table next_sb_late*next_gestage*next_fdeath/ norow nocol nopercent list missing; run;*/
/*proc freq data=ssb.cohort4_all; table next_sb_late*(next_sb_early1 next_sb_late1)/ norow nocol nopercent list missing; run;*/

/*proc freq data=ssb.cohort4_all; table fdeath next_fdeath; run;*/

/*5a. Frequency*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohort4_all;
table fdeath*(next_fdeath next_ptb next_sga)/ nocol nopercent;
table ptb*( next_ptb next_fdeath next_sga)/ nocol nopercent;
table sga*(next_sga next_fdeath next_ptb)/ nocol nopercent;
run;

proc sort data=ssb.cohort4_all; by sb_late; run;
proc freq data=ssb.cohort4_all;
table fdeath*(next_fdeath next_ptb next_sga)/ nocol nopercent;
by sb_late;
run;

ods tagsets.excelxp close;
 
/*5b. Unadjusted risk, accounting for correlation*/
/*Macro for crude risk*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

%macro crude_risk (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
run;
%mend;

%crude_risk (ssb.cohort4_all, fdeath1, next_fdeath1, 'Stillbirth at index Birth');
%crude_risk (ssb.cohort4_all, fdeath1, next_ptb, 'Stillbirth at index Birth');
%crude_risk (ssb.cohort4_all, fdeath1, next_sga, 'Stillbirth at index Birth');

%crude_risk (ssb.cohort4_all, ptb, next_ptb, 'Preterm at index Birth');
%crude_risk (ssb.cohort4_all, ptb, next_fdeath1, 'Preterm at index Birth');
%crude_risk (ssb.cohort4_all, ptb, next_sga, 'Preterm at index Birth');

%crude_risk (ssb.cohort4_all, sga, next_sga, 'SGA at index Birth');
%crude_risk (ssb.cohort4_all, sga, next_fdeath1, 'SGA at index Birth');
%crude_risk (ssb.cohort4_all, sga, next_ptb, 'SGA at index Birth');

ods tagsets.excelxp close;

/*5c. Adjusted risk*/
proc genmod data = ssb.cohort4_all;
	class _brthidhst;
	model next_fdeath1 = fdeath1 mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'Stillbirth at index birth - adjusted' fdeath1 1 -1/exp;
run;

%macro adj_risk (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
run;
%mend;

ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

/**/
%adj_risk (ssb.cohort4_all, fdeath1, next_fdeath1, 'Stillbirth at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, fdeath1, next_ptb, 'Stillbirth at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, fdeath1, next_sga, 'Stillbirth at index Birth - adjusted');

%adj_risk (ssb.cohort4_all, ptb, next_ptb, 'Preterm at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, ptb, next_fdeath1, 'Preterm at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, ptb, next_sga, 'Preterm at index Birth - adjusted');

%adj_risk (ssb.cohort4_all, sga, next_sga, 'SGA at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, sga, next_fdeath1, 'SGA at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, sga, next_ptb, 'SGA at index Birth - adjusted');

ods tagsets.excelxp close;

/*5d. Stratified Sensitivities*/
/*Early/Late Stillbirth*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

%macro crude_risk_sbstrat (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
	by sb_late;
run;
%mend;

proc sort data=ssb.cohort4_all; by sb_late; run; 

%crude_risk_sbstrat (ssb.cohort4_all, fdeath1, next_fdeath1, 'Stillbirth at index Birth - Early/Late SB');
%crude_risk_sbstrat (ssb.cohort4_all, fdeath1, next_ptb, 'Stillbirth at index Birth - Early/Late SB');
%crude_risk_sbstrat (ssb.cohort4_all, fdeath1, next_sga, 'Stillbirth at index Birth - Early/Late SB');

%macro adj_risk_sbstrat (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch;
    estimate &title &exposure 1 -1/exp;
	by sb_late;
run;
%mend;

%adj_risk_sbstrat (ssb.cohort4_all, fdeath1, next_fdeath1, 'Stillbirth at index Birth - adjusted - Early/Late SB');
%adj_risk_sbstrat (ssb.cohort4_all, fdeath1, next_ptb, 'Stillbirth at index Birth - adjusted - Early/Late SB');
%adj_risk_sbstrat (ssb.cohort4_all, fdeath1, next_sga, 'Stillbirth at index Birth - adjusted - Early/Late SB');

/*Restricted early preterm*/
proc freq data=ssb.cohort4_all;
table vpreterm*(next_sga next_ptb next_fdeath1)/ nocol nopercent;
run;

%crude_risk (ssb.cohort4_all, vpreterm, next_ptb, 'Very Preterm at index Birth');
%crude_risk (ssb.cohort4_all, vpreterm, next_fdeath1, 'Very Preterm at index Birth');
%crude_risk (ssb.cohort4_all, vpreterm, next_sga, 'Very Preterm at index Birth');

%adj_risk (ssb.cohort4_all, vpreterm, next_ptb, 'Very Preterm at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, vpreterm, next_fdeath1, 'Very Preterm at index Birth - adjusted');
%adj_risk (ssb.cohort4_all, vpreterm, next_sga, 'Very Preterm at index Birth - adjusted');

ods tagsets.excelxp close;

/*Exposure Preterm birth, outcome early late SB*/
proc sort data=ssb.cohort4_all; by sb_early; run;

ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohort4_all; 
table ptb*(next_sb_early1 next_sb_late1)/ nopercent nocol; 
run;

/*Unadjusted */
proc genmod data = ssb.cohort4_all;
	class _brthidhst;
	model next_sb_early1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

proc genmod data = ssb.cohort4_all;
	class _brthidhst;
	model next_sb_late1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

/*Adjusted*/
proc genmod data = ssb.cohort4_all;
	class _brthidhst;
	model next_sb_early1 = ptb mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB adj' ptb 1 -1/exp;
run;

proc genmod data = ssb.cohort4_all;
	class _brthidhst;
	model next_sb_late1 = ptb mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB adj' ptb 1 -1/exp;
run;

ods tagsets.excelxp close;

/*6. Sensitivity Analyses*/
/*6a. Linked vs. Unlinked births*/
data linkage;
	set ssb.linkage;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\HYPERTENSION.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\ECLAMPSIA.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\DIABETES.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MRACE7C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MEDUC6C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\INSURANCE.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\BATEMANSCORE.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\USBORN.sas";
run;

proc contents data=linkage; run;

/*Define new levels of maternal characteristics for race, education, insurance, age at delivery*/
data linkage2;
set linkage;
select (mrace7c);
	when ('1') mrace5c=1;  
	when ('2') mrace5c=2; 
	when ('5') mrace5c=3;  
	when ('3') mrace5c=4; 
	when ('4') mrace5c=4;
	when ('6') mrace5c=5; 
	when ('7') mrace5c=5;
	when (.) mrace5c=6;
end;
select (delpayer);
	when ('1') delpayer3c = 2;
	when ('2') delpayer3c = 1;
	when ('3') delpayer3c = 3;
	when ('4') delpayer3c = 3;
	when (.) delpayer3c = 4;
end;
select (meduc6c);
	when ('1') meduc4c = 1;
	when ('2') meduc4c = 1;
	when ('3') meduc4c = 2;
	when ('4') meduc4c = 3;
	when ('5') meduc4c = 3;
	when (.) meduc4c = 4;
end;
if mage=. then mage_cat=5;
else if mage < 20 then mage_cat = 1;
else if 30 > mage >= 20 then mage_cat = 2;
else if 40 > mage >= 30 then mage_cat = 3;
else if mage >= 40 then mage_cat = 4;

if newpar >= 5 then parcat = 5;
else parcat = newpar;

if gestage1 < 20 then gest_cat = 1;
else if 20 <= gestage1 < 26 then gest_cat = 2;
else if 26 <= gestage1 < 31 then gest_cat = 3;
else if 31 <= gestage < 37 then gest_cat = 4;
else if 37 <= gestage < 46 then gest_cat = 5;
else gest_cat = 6;

if fdeath = 0 and sga = 0 and ptb=0 then complication = 0; 
else complication = 1;
run; 

/*proc freq data= linkage2; */
/*tables mrace7c*mrace5c delpayer*delpayer3c meduc6c*meduc4c mage*mage_cat prehyp predia gestage1*gest_cat newpar*parcat usborn / nopercent nocol norow list missing; */
/*run; */

/*proc freq data= linkage2;  tables gestage1*gest_cat/ nopercent nocol norow list missing;  run; */

/*Create deduped dataset with one row per unique mother*/
proc sort data = linkage2; by _brthidhst newpar; run; 
data linkage3; set linkage2; by _brthidhst newpar; if first._brthidhst; run;

/*Mother-level statistics*/
proc sort data=linkage3; by fdeath; run; 

/*Define Preterm birth for this population */
data ssb.linkage2;
set linkage3;
if gestage > 36 then ptb = 0;
else if gestage <= 36 then ptb =1;
run;

proc sort data=ssb.linkage2; by linked; run; 
proc freq data=ssb.linkage2; tables SGA fdeath ptb/ norow nocol; format SGA bin. fdeath $bin. ptb bin.; by linked; run;

/*Descriptives for unlinked vs. unlinked*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

/*Live unlinked*/
proc freq data=ssb.linkage2; 
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn parcat gest_cat/ list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp.  parcat parcat. gest_cat gest_cat.;
where fdeath= "0" and linked = 0;
run;

/*Stillborn unlinked*/
proc freq data=ssb.linkage2; 
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn parcat gest_cat/ list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp.  parcat parcat. gest_cat gest_cat.;
where fdeath= "1" and linked = 0;
run;

ods tagsets.excelxp close;

ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

/*Live linked*/
proc freq data=ssb.linkage2; 
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn parcat gest_cat/ list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp.  parcat parcat. gest_cat gest_cat.;
where fdeath= "0" and linked = 1;
run;

/*Stillborn linked*/
proc freq data=ssb.linkage2; 
table mage_cat delpayer3c meduc4c mrace5c predia prehyp usborn parcat gest_cat/ list missing;
format mage_cat mage_cat. delpayer3c delpayer3c. meduc4c meduc4c. mrace5c mrace5c. predia dia. prehyp hyp.  parcat parcat. gest_cat gest_cat.;
where fdeath= "1" and linked = 1;
run;

ods tagsets.excelxp close;

proc means data=ssb.linkage2 mean std median Q1 Q3; var mage; by fdeath; where linked = 0; run;
proc means data=ssb.linkage2 mean std median Q1 Q3; var mage; by fdeath; where linked = 1; run;

/*6b. First and second births only cohort*/
/*Create sensitivity cohort with just parity 1 and 2*/

data ssb.cohortsens; set ssb.cohort4_all; if newpar = 1; run;

proc freq data=ssb.cohortsens; table newpar next_parity; run;

proc sort data = ssb.cohortsens out = check nodupkey; by _brthidhst; run;

/*Frequency output*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohortsens;
table fdeath*(next_fdeath next_ptb  next_sga)/ nocol nopercent;
table ptb*( next_ptb next_fdeath next_sga)/ nocol nopercent;
table sga*(next_sga next_fdeath next_ptb)/ nocol nopercent;
run;

proc sort data=ssb.cohortsens; by sb_late; run;
proc freq data=ssb.cohortsens;
table fdeath*(next_fdeath next_ptb next_sga)/ nocol nopercent;
by sb_late;
run;

/*Unadjusted risk, accounting for correlation*/
/*Macro for crude risk*/
%crude_risk (ssb.cohortsens, fdeath1, next_fdeath1, 'Stillbirth at index Birth');
%crude_risk (ssb.cohortsens, fdeath1, next_ptb, 'Stillbirth at index Birth');
%crude_risk (ssb.cohortsens, fdeath1, next_sga, 'Stillbirth at index Birth');

%crude_risk (ssb.cohortsens, ptb, next_ptb, 'Preterm at index Birth');
%crude_risk (ssb.cohortsens, ptb, next_fdeath1, 'Preterm at index Birth');
%crude_risk (ssb.cohortsens, ptb, next_sga, 'Preterm at index Birth');

%crude_risk (ssb.cohortsens, sga, next_sga, 'SGA at index Birth');
%crude_risk (ssb.cohortsens, sga, next_fdeath1, 'SGA at index Birth');
%crude_risk (ssb.cohortsens, sga, next_ptb, 'SGA at index Birth');

ods tagsets.excelxp close;

/*Adjusted risk*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

%macro adj_risk (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
run;
%mend;

%adj_risk (ssb.cohortsens, fdeath1, next_fdeath1, 'Stillbirth at index Birth - adjusted');
%adj_risk (ssb.cohortsens, fdeath1, next_ptb, 'Stillbirth at index Birth - adjusted');
%adj_risk (ssb.cohortsens, fdeath1, next_sga, 'Stillbirth at index Birth - adjusted');

%adj_risk (ssb.cohortsens, ptb, next_ptb, 'Preterm at index Birth - adjusted');
%adj_risk (ssb.cohortsens, ptb, next_fdeath1, 'Preterm at index Birth - adjusted');
%adj_risk (ssb.cohortsens, ptb, next_sga, 'Preterm at index Birth - adjusted');

%adj_risk (ssb.cohortsens, sga, next_sga, 'SGA at index Birth - adjusted');
%adj_risk (ssb.cohortsens, sga, next_fdeath1, 'SGA at index Birth - adjusted');
%adj_risk (ssb.cohortsens, sga, next_ptb, 'SGA at index Birth - adjusted');

ods tagsets.excelxp close;

/*Stratified Sensitivities*/
/*Early/Late Stillbirth*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

%macro crude_risk_sbstrat (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
	by sb_late;
run;
%mend;

proc sort data=ssb.cohortsens; by sb_late; run; 

%crude_risk_sbstrat (ssb.cohortsens, fdeath1, next_fdeath1, 'Stillbirth at index Birth - Early/Late SB');
%crude_risk_sbstrat (ssb.cohortsens, fdeath1, next_ptb, 'Stillbirth at index Birth - Early/Late SB');
%crude_risk_sbstrat (ssb.cohortsens, fdeath1, next_sga, 'Stillbirth at index Birth - Early/Late SB');

%macro adj_risk_sbstrat (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	model &outcome = &exposure mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate &title &exposure 1 -1/exp;
	by sb_late;
run;
%mend;

%adj_risk_sbstrat (ssb.cohortsens, fdeath1, next_fdeath1, 'Stillbirth at index Birth - adjusted - Early/Late SB');
%adj_risk_sbstrat (ssb.cohortsens, fdeath1, next_ptb, 'Stillbirth at index Birth - adjusted - Early/Late SB');
%adj_risk_sbstrat (ssb.cohortsens, fdeath1, next_sga, 'Stillbirth at index Birth - adjusted - Early/Late SB');

ods tagsets.excelxp close;

/*Restricted early preterm*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

proc freq data=ssb.cohortsens;
table vpreterm*(next_ptb next_fdeath1 next_sga )/ nocol nopercent;
run;

%crude_risk (ssb.cohortsens, vpreterm, next_ptb, 'Very Preterm at index Birth');
%crude_risk (ssb.cohortsens, vpreterm, next_fdeath1, 'Very Preterm at index Birth');
%crude_risk (ssb.cohortsens, vpreterm, next_sga, 'Very Preterm at index Birth');

%adj_risk (ssb.cohortsens, vpreterm, next_ptb, 'Very Preterm at index Birth - adjusted');
%adj_risk (ssb.cohortsens, vpreterm, next_fdeath1, 'Very Preterm at index Birth - adjusted');
%adj_risk (ssb.cohortsens, vpreterm, next_sga, 'Very Preterm at index Birth - adjusted');

/*Exposure Preterm birth, outcome early late SB*/
proc sort data=ssb.cohortsens; by sb_early; run;

proc freq data=ssb.cohortsens; 
table ptb*(next_sb_early1 next_sb_late1)/ nopercent nocol; 
run;

/*Unadjusted */
proc genmod data = ssb.cohortsens;
	class _brthidhst;
	model next_sb_early1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

proc genmod data = ssb.cohortsens;
	class _brthidhst;
	model next_sb_late1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

/*Adjusted*/
proc genmod data = ssb.cohortsens;
	class _brthidhst;
	model next_sb_early1 = ptb mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB adj' ptb 1 -1/exp;
run;

proc genmod data = ssb.cohortsens;
	class _brthidhst;
	model next_sb_late1 = ptb mage_cat delpayer3c meduc4c mrace5c usborn parcat predia prehyp /dist=poisson link=log;
	repeated subject= _brthidhst/corr=exch corrw;
    estimate 'PTB at index birth - stratified SB adj' ptb 1 -1/exp;
run;

ods tagsets.excelxp close;

/*7. IPCW analysis*/
/*7a. Recreate population with women who just had first births and women who had births 1 and 2*/
/*If a woman just had a first birth only, then censored = 1*/
/*exclude those without parity = 1*/
data ipcw1 drop;
set ssb.ipcw1;
if newpar = 1 then output ipcw1;
else output drop;
run;

proc sort data=ipcw1 out=check nodupkey; by _brthidhst; run;

/*Include only singletons, gestational age non missing 20-45 weeks, birthweight non missing 250-9000g*/
/*only keep births with gestational age 20-45 weeks, excluding missing*/
/*only keep births with birth weight 250-9000g, excluding missing*/
/*only keep births with infant sex, excluding missing*/
/*define multiple births and include keep only singleton*/

data ipcw2;
	set ipcw1;
	if _twinB='Y' OR _twinM='Y' OR _twinI='Y' OR Typebth =9 THEN twin=1; else twin = 0;
	if gestage = . then gest_miss = 1; else gest_miss = 0;
	if 0 <= gestage < 20 then gest_lt20 = 1; else gest_lt20 = 0;
	if 45 < gestage then gest_gt45 = 1; else gest_gt45 = 0;
	if bthwght = . then miss_bweight = 1; else miss_bweight = 0;
	if 0 <= bthwght < 250 then bw_lt250 = 1; else bw_lt250 = 0;
	if 9000 <= bthwght then bw_gt9000 = 1; else bw_gt9000 = 0;
	if sex in (1 2) then sex_miss = 0; else sex_miss = 1;
run;

proc freq data = ipcw2;
	table twin gest_miss gest_lt20 gest_gt45 miss_bweight bw_lt250 bw_gt9000 sex_miss;
run;

data ipcw3 drop;
	set ipcw2;
	if twin = 0 and gest_miss = 0 and gest_lt20 = 0 and gest_gt45 = 0 and miss_bweight = 0 and bw_lt250 = 0 
	and bw_gt9000 = 0 and sex_miss = 0 then output ipcw3;
	else output drop;
run;

proc sort data=ipcw3; by _brthidhst; run;
proc sort data=ssb.cohort4_all; by _brthidhst; run;

/*Double check there is no overlapp between the two datasets*/
data test;
merge ssb.cohort4_all (in =a) ipcw3 (in = b);
by _brthidhst;
if  a and b;
run;
/*Expecting 0 observations - no overlapp*/

/*Read in maternal characteristics and redefine to match main dataset*/
data ipcw4;
	set ipcw3;
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\HYPERTENSION.sas";
	  %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\DIABETES.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MRACE7C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\MEDUC6C.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\INSURANCE.sas";
      %INC "D:\Projects\Carmichael-Lee-Data\OSHPD\Constructed\USBORN.sas";
run;

proc contents data=ipcw4; run;

/*Define new levels of maternal characteristics for race, education, insurance, age at delivery + others*/
data ipcw4;
set ipcw4;
select (mrace7c);
	when ('1') mrace5c=1;  
	when ('2') mrace5c=2; 
	when ('5') mrace5c=3;  
	when ('3') mrace5c=4; 
	when ('4') mrace5c=4;
	when ('6') mrace5c=5; 
	when ('7') mrace5c=5;
	when (.) mrace5c=5;
end;
select (delpayer);
	when ('1') delpayer3c = 2;
	when ('2') delpayer3c = 1;
	when ('3') delpayer3c = 3;
	when ('4') delpayer3c = 3;
	when (.) delpayer3c = 3;
end;
select (meduc6c);
	when ('1') meduc4c = 1;
	when ('2') meduc4c = 1;
	when ('3') meduc4c = 2;
	when ('4') meduc4c = 3;
	when ('5') meduc4c = 3;
	when (.) meduc4c = 4;
end;
select (usborn);
	when ('.') usborn3c = 0;
	when ('0') usborn3c = 1;
	when ('1') usborn3c = 2;
end;

if mage=. then mage_cat=5;
else if mage < 20 then mage_cat = 1;
else if 30 > mage >= 20 then mage_cat = 2;
else if 40 > mage >= 30 then mage_cat = 3;
else if mage >= 40 then mage_cat = 4;

if newpar >= 5 then parcat = 5;
else parcat = newpar;

if gestage <= 30 then gest_cat = 1;
else if 30 < gestage <= 36 then gest_cat = 2;
else gest_cat = 3;

run; 

/*proc freq data= ipcw4; */
/*tables mrace7c*mrace5c delpayer*delpayer3c meduc6c*meduc4c mage*mage_cat prehyp predia gestage1*gest_cat newpar*parcat */
/*usborn*usborn3c / nopercent nocol norow list missing; */
/*run; */

/*Define ptb for this group*/
data ipcw4;
set ipcw4;
if gestage > 36 then ptb = 0;
else if gestage <= 36 then ptb =1;
run;

proc freq data=ipcw4; tables SGA fdeath ptb/ norow nocol; format SGA bin. fdeath $bin. ptb bin.; run;

data onebirthonly; set ipcw4;
if fdeath = 0 and sga = 0 and ptb=0 then complication = 0; 
else complication = 1;
run;

/*proc freq data = ssb.onebirthonly; table complication*(ptb fdeath sga)/ nopercent norow; run; */

/*7b. Create a variable for censored status and join datasets (sensitivity cohort+ IPCW population) together*/
data ipcw6; set onebirthonly;
censored = 1;
run;

data main; set ssb.cohortsens;
censored = 0;
run;

data ssb.IPCWfinal;
set main ipcw6;
run;

/*7c. Calculate fitted probability of censoring - first get propensity score, then take inverse*/
proc logistic data=ssb.IPCWfinal;
class mage_cat delpayer3c meduc4c mrace5c usborn3c predia prehyp gest_cat;
model censored (event="0") = mage_cat delpayer3c meduc4c mrace5c usborn3c predia prehyp gest_cat;
output out = pred_cohort pred= ps;
run;

/*Confirm all outcomes are set to missing already - model with drop censored observations */
/*Calculate marginal probability of not being censored*/
proc freq data = pred_cohort;
table censored/out = marg_prob;
run;

data marg_prob;
set marg_prob;
if censored = 0;
marg_prob = PERCENT/100;
run;
 
data pred_cohort2;
if _n_=1 then set marg_prob;
retain marg_prob;
set pred_cohort;
us_ipcw = 1/ps;
ipcw = marg_prob/ps;
run;

/*Assess distribution of weights*/
proc means data=pred_cohort2;
class censored;
var ps ipcw us_ipcw;
run;

proc means data=pred_cohort2;
var ps ipcw us_ipcw;
run;

/*Only care about weights for censored = 0. Some stabilized IPCW are very large - will need to figure out how many and truncate*/
data pred_cohort3; set pred_cohort2; 
if ipcw > 20 then ipcw_truc = 1; else ipcw_truc = 0; 
if ipcw > 20 then ipcw = 20;
run;

proc freq data=pred_cohort3; table ipcw_truc; run;
/*30 observations were truncated*/

proc univariate data=pred_cohort3;
class censored;
var ipcw;
run;

/*7d. Assess positivity assumption using log odds plot*/
/*Generate log odds*/
data pred_cohort3; set pred_cohort3;
logodds = log(ps/(1-ps));
run;

/*Check positivity assumption graphically*/
ods graphics on / obsmax=3000000;

proc sgplot data=pred_cohort3;
scatter x=logodds y=ps /legendlabel="Predicted";
scatter x=logodds y=censored /legendlabel="Observed";
xaxis label = "Log Odds";
yaxis label = "Predicted Probability of Censorship";
title "Predicted Probability of Censorship by Log Odds";
run;

ods graphics off;

/*Save a permanent dataset*/
data ssb.ipcw2; set pred_cohort3; if censored = 0; run;

/*7e. Re run analyses with IPCW*/
/*Macro for crude risk*/
ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

%macro ipcw_risk (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	weight ipcw;
	model &outcome = &exposure /dist=poisson link=log;
	repeated subject= _brthidhst/type = exch;
	estimate &title &exposure 1 -1/exp;
run;
%mend;

%ipcw_risk (ssb.ipcw2, fdeath1, next_fdeath1, 'Stillbirth at index Birth');
%ipcw_risk (ssb.ipcw2, fdeath1, next_ptb, 'Stillbirth at index Birth');
%ipcw_risk (ssb.ipcw2, fdeath1, next_sga, 'Stillbirth at index Birth');

%ipcw_risk (ssb.ipcw2, ptb, next_ptb, 'Preterm at index Birth');
%ipcw_risk (ssb.ipcw2, ptb, next_fdeath1, 'Preterm at index Birth');
%ipcw_risk (ssb.ipcw2, ptb, next_sga, 'Preterm at index Birth');

%ipcw_risk (ssb.ipcw2, sga, next_sga, 'SGA at index Birth');
%ipcw_risk (ssb.ipcw2, sga, next_fdeath1, 'SGA at index Birth');
%ipcw_risk (ssb.ipcw2, sga, next_ptb, 'SGA at index Birth');

ods tagsets.excelxp file="D:\UserData\sbane\3. thesis\results.xls"
options(embedded_titles="yes"
autofilter="1-3"
frozen_headers="3"
frozen_rowheaders="1"
autofit_height="yes"
suppress_bylines="yes") style=normal;

/*Early/Late Stillbirth - exposure stillbirth*/
%macro ipcw_risk_sbstrat (data, exposure, outcome, title);
proc genmod data = &data;
	class _brthidhst;
	weight ipcw;
	model &outcome = &exposure /dist=poisson link=log;
	repeated subject= _brthidhst/covb;
    estimate &title &exposure 1 -1/exp;
	by sb_late;
run;
%mend;

proc sort data=ssb.ipcw2; by sb_late; run; 

%ipcw_risk_sbstrat (ssb.ipcw2, fdeath1, next_fdeath1, 'Stillbirth at index Birth - Early/Late SB');
%ipcw_risk_sbstrat (ssb.ipcw2, fdeath1, next_ptb, 'Stillbirth at index Birth - Early/Late SB');
%ipcw_risk_sbstrat (ssb.ipcw2, fdeath1, next_sga, 'Stillbirth at index Birth - Early/Late SB');

/*Restricted early preterm*/
%ipcw_risk (ssb.ipcw2, vpreterm, next_ptb, 'Very Preterm at index Birth');
%ipcw_risk (ssb.ipcw2, vpreterm, next_fdeath1, 'Very Preterm at index Birth');
%ipcw_risk (ssb.ipcw2, vpreterm, next_sga, 'Very Preterm at index Birth');

/*Exposure Preterm birth, outcome early late SB*/
proc sort data=ssb.ipcw2; by sb_early; run;

proc genmod data = ssb.ipcw2;
	class _brthidhst;
	weight ipcw;
	model next_sb_early1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/covb;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

proc genmod data = ssb.ipcw2;
	class _brthidhst;
	weight ipcw;
	model next_sb_late1 = ptb /dist=poisson link=log;
	repeated subject= _brthidhst/covb;
    estimate 'PTB at index birth - stratified SB' ptb 1 -1/exp;
run;

ods tagsets.excelxp close;
