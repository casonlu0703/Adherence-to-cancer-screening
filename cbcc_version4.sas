/*libname cbcc "G:\CBCC";*/
libname cbcc "C:\CBCC";

proc format;
value ins_type
	1="Government Insurance"
	2="Private Insurance"
	3="Uninsured"
	.="Others"
	;
value ethnic
	1="White"
	2="Black/African American"
	3="Asian"
	4="Hispanic"
	5="Others"
	;
value age_gp
	1="40-49"
	2="50-64"
	3="65+"
	;
	run;


*****************    BASELINE    ******************;
libname cbcc "C:\CBCC";
data analyze_0;
	set cbcc.analyze_0;
	run;

proc sort data=analyze_0; 
	by exam_year PTID EXAMDATE;
run;

data analyze_tr;
set analyze_0;
by exam_year PTID EXAMDATE;
if first.PTID then time=0;
time+1;
if PROCID="M-SCRx" then PROCID="M-SCR";
run;

proc freq data=analyze_tr;
table 
time*exam_year
PROCID;
run;
proc print data=analyze_tr(obs=50); run;

proc freq data=analyze_0;
table PROCID;
run;

%macro trans(year,i);
	data exam_&year.(rename=(EXAMID=EXAMID_&i. EXAMDATE=EXAMDATE_&i. PROCID=PROCID_&i. IMP=IMP_&i. FU=FU_&i. DENSITY=DENSITY_&i. time=time_&i.));
		set analyze_tr(drop=F8 where=(exam_year=&year.));
		by exam_year PTID EXAMDATE;
		if last.PTID; ** checked by proc sql step that observations are either duplicate or last one is valid;
		if imp in (1,2) & PROCID in ("M-SCR", "M-SCR-D", "M-SCR-I") 
				then output;
	run;
%mend trans;
%trans(2011,0)
%trans(2012,1)
%trans(2013,2)
%trans(2014,3)
%trans(2015,4);

/* 3 have 2 visits in 2011, the last visit is valid screening test */
proc sql;
	select * from exam_2011 where PTID in (select PTID from exam_2011 where time_0>1);
	
	select * from exam_2012 where PTID in (select PTID from exam_2012 where time_1>1);
	
	select * from exam_2013 where PTID in (select PTID from exam_2013 where time_2>1);
	
	select * from exam_2014 where PTID in (select PTID from exam_2014 where time_3>1);
	
	select * from exam_2015 where PTID in (select PTID from exam_2015 where time_4>1);
	quit;

data analyze_2;
	set exam_2011(rename=(EXAMID_0=EXAMID EXAMDATE_0=EXAMDATE PROCID_0=PROCID IMP_0=IMP FU_0=FU DENSITY_0=DENSITY))
		exam_2012(rename=(EXAMID_1=EXAMID EXAMDATE_1=EXAMDATE PROCID_1=PROCID IMP_1=IMP ))
		exam_2013(rename=(EXAMID_2=EXAMID EXAMDATE_2=EXAMDATE PROCID_2=PROCID IMP_2=IMP ))
		exam_2014(rename=(EXAMID_3=EXAMID EXAMDATE_3=EXAMDATE PROCID_3=PROCID IMP_3=IMP ))
		exam_2015(rename=(EXAMID_4=EXAMID EXAMDATE_4=EXAMDATE PROCID_4=PROCID IMP_4=IMP ))
		;
	keep PTID EXAMID EXAMDATE PROCID IMP FU DENSITY DOB CITY ADR_STAT ZIP SEX INS CAT1 FACILITY F10 exam_year age ETHNIC HISPANIC ins_type ethnic_type age_group ;
run;

proc sort data=analyze_2;
by PTID EXAMDATE;
run;

data analyze_3;
	set analyze_2;
	by 	PTID EXAMDATE;
	if first.PTID then time=0;
		time+1;
run;

proc freq data=analyze_3; table time*exam_year; run;

data exam_1(rename=(EXAMID=EXAMID_0 EXAMDATE=EXAMDATE_0 PROCID=PROCID_0 IMP=IMP_0))
	 exam_2(rename=(EXAMID=EXAMID_1 EXAMDATE=EXAMDATE_1 PROCID=PROCID_1 IMP=IMP_1))
	 exam_3(rename=(EXAMID=EXAMID_2 EXAMDATE=EXAMDATE_2 PROCID=PROCID_2 IMP=IMP_2))
	 exam_4(rename=(EXAMID=EXAMID_3 EXAMDATE=EXAMDATE_3 PROCID=PROCID_3 IMP=IMP_3))
	 exam_5(rename=(EXAMID=EXAMID_4 EXAMDATE=EXAMDATE_4 PROCID=PROCID_4 IMP=IMP_4))
	 ;
	set analyze_3;
	if ethnic_type in (1,3,5) then ethnic_type=1;** White include White=1 & Asian=3 & Other=5;
	if time=1 then output exam_1;
	if time=2 then output exam_2;
	if time=3 then output exam_3;
	if time=4 then output exam_4;
	if time=5 then output exam_5;
run;

**************              Adherence             **********************;

data analyze_fu(drop=exam_year time);
	merge exam_1-exam_5;
	by PTID;	
run;

proc print data=analyze_fu(obs=10); run;

**************       ACR       *******************;

data analyze_fu_adh;
	set analyze_fu;
	
	array date{*} EXAMDATE_0-EXAMDATE_4;
	array PROC{*} PROCID_0-PROCID_4;
	array IMP{*} IMP_0-IMP_4;
	array adh{*} adh_1-adh_4;
	array dur{*} dur_1-dur_4;

	** adherence: patients with (1)former screening is M_SCR M_SCR_D M_SCR_I, (2)imp=1 or 2;
	do i=1 to 4;
		dur[i]=intck("month",DATE[i],DATE[i+1]);
		** adh=0 no fu, adh=1 has fu within 13 months, adh=2 has fu over 13 months;
		if 0 lt dur[i] le 13 then adh[i]=1;
			else if dur[i] gt 13 then adh[i]=2;
				else adh[i]=0;
	end;

	drop i;
	
	** mean adherent visiting times ;
	adh_mean_ACR=(adh_1+adh_2+adh_3+adh_4)/4;

run;

proc contents data=analyze_fu_adh; run;
proc print data=analyze_fu_adh(obs=100); run;

proc freq data=analyze_fu_adh;
	table adh_1*dur_1 adh_2*dur_2 adh_3*dur_3 adh_4*dur_4;
	run;

proc freq data=analyze_fu_adh(where=(adh_1 in (1,2)));
	table  age_group;
/*ethnic_type ins_type ADR_STAT PROCID_1 imp_1;*/
	ods output  OneWayFreqs=freq;
	run;
	
	data freq1(rename=(age_group=group));
		set freq;
		keep age_group Frequency Percent CumFrequency;
		var=age_group;
		run;

	proc print; run;

%macro freq(data, class);
	proc freq data=&data.;
		table  &class.;
		ods output  OneWayFreqs=freq;
		run;
		
	data freq1(rename=(&class.=group));
		set freq;
		keep var &class. Frequency Percent CumFrequency;
		var="&class";
		run;
	proc append base=all_freq data=freq1 force; run;
%mend freq;

/* ACR baseline visiting*/
proc delete data=freq; run;
proc delete data=freq1; run;
proc delete data=all_freq; run;
%freq(exam_1,age_group)
%freq(exam_1,ethnic_type)
%freq(exam_1,ins_type)
%freq(exam_1,ADR_STAT)
%freq(exam_1,imp_0)

proc print data=all_freq; run;

proc export data=all_freq
   outfile='C:\CBCC\ACR.xlsx'
   dbms=xlsx
   replace;
   sheet="baseline";
run;


/* ACR adherent visiting*/
proc delete data=freq; run;
proc delete data=freq1; run;
proc delete data=all_freq; run;
%freq(analyze_fu_adh(where=(adh_1=1)),age_group)
%freq(analyze_fu_adh(where=(adh_1=1)),ethnic_type)
%freq(analyze_fu_adh(where=(adh_1=1)),ins_type)
%freq(analyze_fu_adh(where=(adh_1=1)),ADR_STAT)
**%freq(analyze_fu_adh(where=(adh_1=1)),PROCID_1);
%freq(analyze_fu_adh(where=(adh_1=1)),imp_1)

proc print data=all_freq; run;

proc export data=all_freq
   outfile='C:\CBCC\ACR.xlsx'
   dbms=xlsx
   replace;
   sheet="adh1";
run;


/* ACR adherent visiting*/
proc delete data=freq; run;
proc delete data=freq1; run;
proc delete data=all_freq; run;
%freq(analyze_fu_adh(where=(adh_2=1)),age_group)
%freq(analyze_fu_adh(where=(adh_2=1)),ethnic_type)
%freq(analyze_fu_adh(where=(adh_2=1)),ins_type)
%freq(analyze_fu_adh(where=(adh_2=1)),ADR_STAT)
**%freq(analyze_fu_adh(where=(adh_2=1)),PROCID_2);
%freq(analyze_fu_adh(where=(adh_2=1)),imp_2)

proc print data=all_freq; run;

proc export data=all_freq
   outfile='C:\CBCC\ACR.xlsx'
   dbms=xlsx
   replace;
   sheet="adh2";
run;


/* ACR adherent visiting*/
proc delete data=freq; run;
proc delete data=freq1; run;
proc delete data=all_freq; run;
%freq(analyze_fu_adh(where=(adh_3=1)),age_group)
%freq(analyze_fu_adh(where=(adh_3=1)),ethnic_type)
%freq(analyze_fu_adh(where=(adh_3=1)),ins_type)
%freq(analyze_fu_adh(where=(adh_3=1)),ADR_STAT)
**%freq(analyze_fu_adh(where=(adh_3=1)),PROCID_3);
%freq(analyze_fu_adh(where=(adh_3=1)),imp_3)

proc print data=all_freq; run;

proc export data=all_freq
   outfile='C:\CBCC\ACR.xlsx'
   dbms=xlsx
   replace;
   sheet="adh3";
run;


/* ACR adherent visiting*/
proc delete data=freq; run;
proc delete data=freq1; run;
proc delete data=all_freq; run;
%freq(analyze_fu_adh(where=(adh_4=1)),age_group)
%freq(analyze_fu_adh(where=(adh_4=1)),ethnic_type)
%freq(analyze_fu_adh(where=(adh_4=1)),ins_type)
%freq(analyze_fu_adh(where=(adh_4=1)),ADR_STAT)
**%freq(analyze_fu_adh(where=(adh_4=1)),PROCID_4);
%freq(analyze_fu_adh(where=(adh_4=1)),imp_4)

proc print data=all_freq; run;

proc export data=all_freq
   outfile='C:\CBCC\ACR.xlsx'
   dbms=xlsx
   replace;
   sheet="adh4";
run;

*********************      Mean Adherent visiting times      ************************;

%macro anova(var, class, data);
	proc means data=&data. mean std median;
		var &var.;
		class &class.;
		ods output Summary=summary;
	 quit;

	proc print data=summary; run;
		data summary;
			set summary(rename=(&class=group));
			var="&class.";
		 run;

	proc append base=all_summary data=summary force; run;
	
	** mean visiting times & ANOVA test;
	proc anova data=&data.;
		class &class.;
		model &var.=&class.;
		ods output ModelANOVA=p(keep=source probf);
	 quit;
	proc append base=all_p data=p force; run;

%mend anova;

ods graphics off;

**** ACR;
%let data=analyze_fu_adh;
%let var=adh_mean_ACR;

proc means data=&data. mean std;
var &var.;
run;

proc delete data=all_summary summary all_p p; run;

%anova(&var., ethnic_type, &data.)
%anova(&var., age_group, &data.)
%anova(&var., ins_type, &data.)
%anova(&var., ADR_STAT, &data.)

proc print data=all_summary; run;
proc print data=all_p; run;

proc export data=all_summary
   outfile='C:\CBCC\mean adh.xlsx'
   dbms=xlsx
   replace;
   sheet="ACR means";
run;

proc export data=all_p
   outfile='C:\CBCC\mean adh.xlsx'
   dbms=xlsx
   replace;
   sheet="ACR p";
run;

*********************      Bowker Test      ************************;

data analyze_fu_adh_1;
	set analyze_fu_adh;
	if adh_1=1 then adh_1=1; else adh_1=0;
	if adh_2=1 then adh_2=1; else adh_2=0;
	if adh_3=1 then adh_3=1; else adh_3=0;
	if adh_4=1 then adh_4=1; else adh_4=0;
run;

data analyze_fu_uspstf_1;
	set analyze_fu_uspstf;
	if adh_u_1=1 then adh_u_1=1; else adh_u_1=0;
	if adh_u_2=1 then adh_u_2=1; else adh_u_2=0;
run;

%macro bowker_test(data, class, var1, var2);
	proc freq data=&data.;
		tables &class.*&var1.*&var2. / agree;
		exact mcnem;
		ods output McNemarsTest=MN_test;
	run;
	data MN_test;
		set MN_test(where=(Name1="XP_MCNEM"));
		informat var $12.;
		format var $12.;
		var="&class";
		run;
	proc append base=MN_pvalue data=MN_test force; run;
%mend;

%macro all_class(data, class1, class2, class3, class4, var1, var2);
	proc delete data=MN_test; run;
	proc delete data=MN_pvalue; run;
	%bowker_test(&data, &class1, &var1, &var2);
	%bowker_test(&data, &class2, &var1, &var2);
	%bowker_test(&data, &class3, &var1, &var2);
	%bowker_test(&data, &class4, &var1, &var2);
	proc print data=MN_pvalue; run;
%mend;

%all_class(analyze_fu_adh_1, age_group, ethnic_type, ins_type, ADR_STAT, adh_1, adh_2)
%all_class(analyze_fu_adh_1, age_group, ethnic_type, ins_type, ADR_STAT, adh_2, adh_3)
%all_class(analyze_fu_adh_1, age_group, ethnic_type, ins_type, ADR_STAT, adh_3, adh_4)

proc freq data=analyze_fu_adh_1;
	tables ethnic_type*adh_2*adh_3 / agree;
	exact mcnem;
	ods output McNemarsTest=MN_test;
run;
proc print data=MN_test; run;

data acr_adh1;
	set analyze_fu_adh(keep=PTID age_group ethnic_type ins_type ADR_STAT PROCID_1 imp_1 adh_1
						where=(ADR_STAT ne "WV"));
	if adh_1=1 then adh=1;
		else adh=0;
	if ethnic_type in (1,3,5) then ethnic_type=1;** ** White include White=1 & Asian=3 & Other=5;
	run;

proc freq data=acr_adh1;
tables ethnic_type;
run;

data uspstf_adh1;
	set analyze_fu_uspstf(keep=PTID age age_group ethnic_type ins_type ADR_STAT PROCID_1 imp_1 adh_u_1
						where=(ADR_STAT ne "WV"));
	if adh_u_1=1 then adh=1;
		else adh=0;
	if ethnic_type in (1,3,5) then ethnic_type=1;** White include White=1 & Asian=3 & Other=5;
run;
proc print data=uspstf_adh1; run;


** CRUDE ODDS RATIOS ;
%macro logis_reg(data,var,ref,y);
	proc logistic data=&data.;
	class &var.(ref=&ref.);
	model &y.=&var.;
	ods output Stat.Logistic.OddsRatios=or_test1;
	run;
	quit;
	proc append base=crude_or data=or_test1 force; run;
%mend logis_reg;

proc delete data=crude_or; run;
proc delete data=or_test1; run;

%logis_reg(acr_adh1,age_group,'65+',adh(ref='0'));
%logis_reg(acr_adh1,ethnic_type,'Black/African American',adh(ref='0'));
%logis_reg(acr_adh1,ins_type,'Private Insurance',adh(ref='0'));
%logis_reg(acr_adh1,ADR_STAT,'DC',adh(ref='0'));
%logis_reg(acr_adh1,imp_1,'1',adh(ref='0'));

proc print data=crude_or; run;

proc export data=crude_or
   outfile='C:\CBCC\odds ratios for fu1_2.xlsx'
   dbms=xlsx
   replace;
   sheet="ACR_crude_or";
run;

proc delete data=crude_or; run;
proc delete data=or_test1; run;

%logis_reg(uspstf_adh1,age_group,'65+',adh(ref='0'));
%logis_reg(uspstf_adh1,ethnic_type,'Black/African American',adh(ref='0'));
%logis_reg(uspstf_adh1,ins_type,'Private Insurance',adh(ref='0'));
%logis_reg(uspstf_adh1,ADR_STAT,'DC',adh(ref='0'));
%logis_reg(uspstf_adh1,imp_1,'1',adh(ref='0'));

proc print data=crude_or; run;

proc export data=crude_or
   outfile='C:\CBCC\odds ratios for fu1_2.xlsx'
   dbms=xlsx
   replace;
   sheet="USPSTF_crude_or";
run;

** ADJUSTED ODDS RATIOS;

proc logistic data=acr_adh1;
class age_group(ref='65+') ethnic_type(ref='Black/African American') ins_type(ref='Private Insurance') ADR_STAT(ref='DC') imp_1(ref='1');
model adh(ref='0')= age_group ethnic_type ins_type ADR_STAT imp_1;
ods output Stat.Logistic.OddsRatios=adjusted_or;
run;

proc export data=adjusted_or
   outfile='C:\CBCC\odds ratios for fu1_2.xlsx'
   dbms=xlsx
   replace;
   sheet="ACR_adjusted_or";
run;


proc logistic data=uspstf_adh1;
class age_group(ref='65+') ethnic_type(ref='Black/African American') ins_type(ref='Private Insurance') ADR_STAT(ref='DC') imp_1(ref='1');
model adh(ref='0')= age_group ethnic_type ins_type ADR_STAT imp_1;
ods output Stat.Logistic.OddsRatios=adjusted_or;
run;

proc export data=adjusted_or
   outfile='C:\CBCC\odds ratios for fu1_2.xlsx'
   dbms=xlsx
   replace;
   sheet="USPSTF_adjusted_or";
run;
