** define the library as the folder where datasets saved;
libname alsdata "C:\Users\jl2309\Desktop\ALS\ALS final";

** baseline dataset includes all records at baseline;
data baseline;
	set alsdata.baseline;
	run;
** sample standard deviations were used in the formula of zAL;
proc means data=baseline mean std;
var waist_circumference_cm_0 systolic_0 diastolic_0 fasting_glucose_0 trig_0 bmi_0 hdl_0 hscrp_0 ;
run;


***********************************************************************************;
**						Baseline characteristics (TABLE2)						   ;
***********************************************************************************;

** number of patients in each category ;
proc freq data=baseline;
table age_group education marital smoking walking_mins_group famca_breast abs_risk_group mammogram_new bp_risk cholesterol_new menopausal_symptoms_new;
run;

** This macro get the mean values of AL and zAL by categories of each baseline characteristics;
%macro anova(var, data);
	proc means data=&data. mean std median;
		var ALS zals;
		class &var.;
		ods output Summary=summary;
	 quit;

	data summary;
		set summary(rename=(&var.=group));
		var="&var.";
	 run;
	proc append base=bsl_summary data=summary force; run;
	
	** mean AL & ANOVA test;
	proc anova data=&data.;
		class &var.;
		model als=&var.;
		ods output ModelANOVA=als_p(keep=source probf);
	 quit;
	proc append base=bsl_als_p data=als_p force; run;

	** mean zAL & ANOVA test;
	proc anova data=&data.;
		class &var.;
		model zals=&var.;
		ods output ModelANOVA=zals_p(keep=source probf);
	 quit;
	proc append base=bsl_z_p data=zals_p force; run;

%mend anova;

%let data=baseline;
%put &data;
proc delete data=bsl_summary summary; run;
proc delete data=bsl_als_p als_p bsl_z_p zals_p; run;

ods graphics off;
%anova(menopausal_symptoms_new,&data.)
%anova(age_group,&data.)
%anova(education,&data.)
%anova(marital,&data.)
%anova(smoking,&data.)
%anova(walking_mins_group,&data.); 
%anova(famca_breast,&data.);
%anova(abs_risk_group,&data.)
%anova(bp_risk,&data.)
%anova(cholesterol_new,&data.)
%anova(mammogram_new,&data.)

proc print data=bsl_summary; run;
proc print data=bsl_als_p; run;
proc print data=bsl_z_p;run;
proc export data=bsl_summary
   outfile='C:\Users\jl2309\Desktop\ALS\ALS final\table1.xlsx'
   dbms=xlsx
   replace;
   sheet="bsl_summary";
run;
proc export data=bsl_als_p
   outfile='C:\Users\jl2309\Desktop\ALS\ALS final\table1.xlsx'
   dbms=xlsx
   replace;
   sheet="bsl_als_p";
run;
proc export data=bsl_z_p
   outfile='C:\Users\jl2309\Desktop\ALS\ALS final\table1.xlsx'
   dbms=xlsx
   replace;
   sheet="bsl_z_p";
run;


***********************************************************************************;
**						Baseline and 6-month change (TABLE3)						   ;
***********************************************************************************;

** diff_bsl_f2 dataset includes records at baseline and 6-months followup, change in AL components, AL and zAL included ;
** all changes are calculated as 6months minus baseline;

data diff_bsl_f2;
	set alsdata.diff_bsl_f2;
run;
proc contents data=diff_bsl_f2; run;
ods graphics off;

proc glm data=diff_bsl_f2;
class assignment;
model zals_diff=assignment zals_0;
means assignment;
contrast 'Control vs Supervised Exercise'  Assignment -1 0 1;
contrast 'Control vs Home-Based Exercise'  Assignment -1 1 0;
ods output  Contrasts=total_contrasts  Means=total_means ;
quit;

proc glm data=diff_bsl_f2(where=(famca_breast=1));
class assignment;
model zals_diff=assignment zals_0;
means assignment;
contrast 'Control vs Supervised Exercise'  Assignment -1 0 1;
contrast 'Control vs Home-Based Exercise'  Assignment -1 1 0;
ods output  Contrasts=famca_contrasts  Means=famca_means ;
quit;
proc print data=famca_contrasts; run;
proc print data=famca_means; run;

proc glm data=diff_bsl_f2(where=(famca_breast=2));
class assignment;
model zals_diff=assignment zals_0;
means assignment;
contrast 'Control vs Supervised Exercise'  Assignment -1 0 1;
contrast 'Control vs Home-Based Exercise'  Assignment -1 1 0;
ods output  Contrasts=nofamca_contrasts  Means=nofamca_means ;
quit;
proc print data=nofamca_contrasts; run;
proc print data=nofamca_means; run;

%macro label(data, value);
	data &data.;
		set &data.;
		sample="&value.";
	run;
%mend;
%label(total_contrasts, total_population)
%label(total_means, total_population)
%label(famca_contrasts, fm_hx_brca)
%label(famca_means, fm_hx_brca)
%label(nofamca_contrasts, nofm_hx_brca)
%label(nofamca_means, nofm_hx_brca)

data contrasts;
	set total_contrasts nofamca_contrasts famca_contrasts;
	proc print;
run;

data means;
	set total_means nofamca_means famca_means;
	proc print;
run;

proc export data=contrasts
   outfile='C:\Users\jl2309\Desktop\ALS\ALS final\6month change.xlsx'
   dbms=xlsx
   replace;
   sheet="p value";
run;
proc export data=means
   outfile='C:\Users\jl2309\Desktop\ALS\ALS final\6month change.xlsx'
   dbms=xlsx
   replace;
   sheet="mean zAL";
run;
