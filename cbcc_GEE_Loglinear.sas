***************************************************************************************
					GEE: modeling on probability of adherence     
***************************************************************************************;

**************       ACR       *******************;

data acr_gee_1(rename=(adh_1=adh time_1=time) drop=adh_2 adh_3 adh_4 time_2 time_3 time_4)
	acr_gee_2(rename=(adh_2=adh time_2=time) drop=adh_1 adh_3 adh_4 time_1 time_3 time_4)
	acr_gee_3(rename=(adh_3=adh time_3=time) drop=adh_1 adh_2 adh_4 time_1 time_2 time_4)
	acr_gee_4(rename=(adh_4=adh time_4=time) drop=adh_1 adh_2 adh_3 time_1 time_2 time_3)
;
	set analyze_fu_adh(keep=PTID ins_type ethnic_type age_group ADR_STAT adh_1 adh_2 adh_3 adh_4 
						where=(ADR_STAT ne "WV"));
	time_1=1; time_2=2; time_3=3; time_4=4;
run;

data acr_gee;
	set acr_gee_1-acr_gee_4;
	if adh ne 1 then adh=0;
run;

proc sort data=acr_gee; by PTID; run;

proc print data=acr_gee(obs=100); run;

proc genmod descending data=acr_gee;
	class age_group time PTID;
	model adh = time age_group time*age_group / link=logit dis=bin type3;
	repeated subject=PTID / type=UN;
run;
proc genmod descending data=acr_gee;
	class ethnic_type time PTID;
	model adh = time ethnic_type time*ethnic_type / link=logit dis=bin type3;
	repeated subject=PTID / type=UN;
run;
proc genmod descending data=acr_gee;
	class ins_type time PTID;
	model adh = time ins_type time*ins_type / link=logit dis=bin type3;
	repeated subject=PTID / type=UN;
run;
proc genmod descending data=acr_gee;
	class ADR_STAT time PTID;
	model adh = time ADR_STAT time*ADR_STAT / link=logit dis=bin type3;
	repeated subject=PTID / type=UN;
run;

** interactions with time ;
proc genmod descending data=acr_gee;
	class age_group ethnic_type ins_type ADR_STAT time PTID;
	model adh = time age_group ethnic_type ins_type ADR_STAT time*ADR_STAT time*ins_type time*ethnic_type time*age_group / link=logit dis=bin type3;
	repeated subject=PTID / type=exch;
run;


***************************************************************************************
		Loglinear model test for trend in # of adherent patients (count data)    
***************************************************************************************;

**************       ACR       *******************;

data acr_adh_age;
	input group $5. fu count;
	datalines;
40-49	1	165
40-49	2	88
40-49	3	53
40-49	4	20
50-64	1	244
50-64	2	145
50-64	3	88
50-64	4	36
>=65	1	30
>=65	2	20
>=65	3	10
>=65	4	7
;
proc print; run;

proc catmod order=internal;
	weight count;
	model group*fu=_response_ / noresponse noiter;
	loglin group|fu;
run;

data acr_adh_ethnic;
	input group $8. fu count;
	datalines;
AA      	1	201
AA      	2	114
AA      	3	82
AA      	4	33
Others		1	16
Others		2	8
Others		3	5
Others		4	1
Hispanic	1	222
Hispanic	2	131
Hispanic	3	64
Hispanic	4	29
;
proc print; run;
proc catmod order=internal;
	weight count;
	model group*fu=_response_ / noresponse noiter;
	loglin group|fu;
run;

data acr_adh_ins;
	input group $7. fu count;
	datalines;
gov 		1	169
gov 		2	106
gov 		3	73
gov 		4	27
private		1	55
private		2	33
private		3	27
private		4	12
unins		1	215
unins		2	114
unins		3	51
unins		4	24
;
proc print; run;
proc catmod order=internal;
	weight count;
	model group*fu=_response_ / noresponse noiter;
	loglin group|fu;
run;

data acr_adh_state;
	input group $ fu count;
	datalines;
DC		1	198
DC		2	111
DC		3	79
DC		4	31
MD		1	182
MD		2	107
MD		3	60
MD		4	28
VA		1	59
VA		2	35
VA		3	12
VA		4	4
;
proc print; run;

proc catmod order=internal;
	weight count;
	model group*fu=_response_ / noresponse noiter;
	loglin group|fu;
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

%all_class(analyze_fu_uspstf_1, age_group, ethnic_type, ins_type, ADR_STAT, adh_u_1, adh_u_2)
