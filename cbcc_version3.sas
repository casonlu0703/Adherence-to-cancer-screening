
libname cbcc "G:\CBCC";

data examdate;
set cbcc.examdate;
run;
data dob;
set cbcc.dob;
run;

proc print data=examdate(obs=20); run;
proc print data=dob(obs=20); run;

proc contents data=examdate; run;

*******************************************************
** Section1 Flow chart: get the analytical sample	 **
*******************************************************
;
** extract examine year;
** include pts in 2011 with PROCID=(M-SCR, M-SCR-D, M-SCR-I) & IMP=1|2;
** by year, see for each pts, diagnosis exam first or screening exam first;

proc sort data=examdate; by PTID; run;
proc sort data=dob; by PTID; run;

data examdate_pre_0;
merge examdate(in=ina) dob(in=inb);
by PTID;
exam_year=year(examdate);
age=round(yrdif(dob, "01Jan2011"d));
if age ge 40 then output;
run;
proc print data=examdate_pre_0(obs=20); run;

proc sort data=examdate_pre_0; by exam_year PTID; run;
data examdate_year_times;
	set examdate_pre_0;
	by exam_year PTID examdate;
		if first.PTID then time=0;
			time+1;
	run;
proc print data=examdate_year_times(obs=100); run;

/* type of exam by visit by year for patients with multiple visits per year */
proc freq data=examdate_year_times(where=(time ge 2));
	tables PROCID*time;
	by exam_year;
	run;

** exam times by year;
data exam_2011 exam_2012 exam_2013 exam_2014 exam_2015;
set examdate_pre_0;
if exam_year=2011 then output exam_2011;
if exam_year=2012 then output exam_2012;
if exam_year=2013 then output exam_2013;
if exam_year=2014 then output exam_2014;
if exam_year=2015 then output exam_2015;
run;
proc sql;
 select count(distinct PTID) from exam_2011;
 select count(distinct PTID) from exam_2012;
 select count(distinct PTID) from exam_2013;
 select count(distinct PTID) from exam_2014;
 select count(distinct PTID) from exam_2015;
quit;


** first exam in one year is diagnosis or screening;
%macro multiple_exams(dataset, year);
	** select out PTID with multiple exams within one year;
	data multi_&year.(where=(time=2) keep=PTID);
			set &dataset.;
			by PTID examdate;
			if first.PTID then time=0;
			time+1;
		run;
	data first_&year.;
			merge &dataset.(in=ina) multi_&year. (in=inb keep=PTID);
			by PTID;
			if ina & inb;
			if first.PTID;
		run;
	proc freq data=first_&year.;
		tables PROCID;
		run;

	data first_1_&year.;
			merge &dataset.(in=ina) multi_&year. (in=inb keep=PTID);
			by PTID;
			if ina & inb;
		run;
%mend;

%multiple_exams(exam_2011,2011)
%multiple_exams(exam_2012,2012)
%multiple_exams(exam_2013,2013)
%multiple_exams(exam_2014,2014)
%multiple_exams(exam_2015,2015)
proc export data=first_1_2011
	dbms=xlsx
	outfile="G:\CBCC\first_1_2011.xlsx"
	replace;
run;
proc export data=first_1_2012
	dbms=xlsx
	outfile="G:\CBCC\first_1_2012.xlsx"
	replace;
run;
proc export data=first_1_2013
	dbms=xlsx
	outfile="G:\CBCC\first_1_2013.xlsx"
	replace;
run;
proc export data=first_1_2014
	dbms=xlsx
	outfile="G:\CBCC\first_1_2014.xlsx"
	replace;
run;
proc export data=first_1_2015
	dbms=xlsx
	outfile="G:\CBCC\first_1_2015.xlsx"
	replace;
run;

** get the analytical dataset and # of pts for flowchart;
data examdate_pre_1 exam_out_diag exam_out_imp;
set examdate_pre_0(where=(exam_year=2011));
if PROCID in ("M-SCR", "M-SCR-D", "M-SCR-I") then do;
		if IMP in (1,2) then output examdate_pre_1;
		else output exam_out_imp;
	end;
else output exam_out_diag;
run;
proc sql;
 select count(distinct PTID) from examdate_pre_0;
 select count(distinct PTID) from examdate_pre_1;
 select count(distinct PTID) from exam_out_diag;
 select count(distinct PTID) from exam_out_imp;
quit;
proc contents data=cbcc.examdate_2; run;

*******************************************************
**		transpose examdate, vertical->horizontal     **
*******************************************************
;

proc sort data=examdate;
by PTID EXAMDATE;
run;

proc print data=examdate; run;

data examdate_tr;
set examdate;
by PTID EXAMDATE;
if first.PTID then time=0;
time+1;
run;

proc print data=examdate_tr(obs=50); run;

%macro trans(i);
	data exam_&i.(rename=(EXAMID=EXAMID_&i. EXAMDATE=EXAMDATE_&i. PROCID=PROCID_&i. IMP=IMP_&i. FU=FU_&i. DENSITY=DENSITY_&i.));
		set examdate_tr(drop=F8);
		if time=&i. then do;
				time_&i.=1;
				output;
			end;
		drop time;
	run;
%mend trans;

%trans(1);%trans(2);%trans(3);%trans(4);%trans(5);%trans(6);%trans(7);%trans(8);

data examdate_1;
merge exam_1-exam_8;
by PTID;
array times{8} time_1-time_8;
examtimes=sum(of times(*));
run;

proc print; run;

proc freq data=examdate_1;
tables examtimes;
run;

proc export data=examdate_1 
	outfile="C:\Users\jl2309\Desktop\PEDLAR\CBCC\examdate_1.xlsx"
	dbms=xlsx
	replace;
run;


*******************************************************
**     	duration of any two adjacent exams           **
*******************************************************
;
data examdate_2;
set examdate_1;
array delta{7} delta_1-delta_7;
array examdate{8} examdate_1-examdate_8;
do i=1 to 7;
	if examdate[i+1] ne . then do;
		delta[i]=intck("day",examdate[i],examdate[i+1]);
	end;
end;
drop i;
run;

proc print data=examdate_2(obs=20); run;

proc export data=examdate_2
	outfile="C:\Users\jl2309\Desktop\PEDLAR\CBCC\examdate_daydiff"
	dbms=xlsx
	replace;
run;

proc format;
value duration
	low-<183 = "< 1/2 year"
	183-<365 = "< 1 year"
	365-<730 = "< 2 year"
	730-high = ">= 2 year"
	;
run;

data examdate_3;
set examdate_2;
label delta_1="duration of 1st/2nd exams"
	  delta_2="duration of 2nd/3rd exams"
	  delta_3="duration of 3rd/4th exams"
	  delta_4="duration of 4th/5th exams"
	  delta_5="duration of 5th/6th exams"
	  delta_6="duration of 6th/7th exams"
	  delta_7="duration of 7th/8th exams"
	  ;
format delta_1-delta_7 duration.;
run;

proc print data=examdate_3(obs=20); run;

/* Table 2 */
proc freq data=examdate_3;
table delta_1-delta_7;
run;


*******************************************************
**     	         drop-off pattern                    **
*******************************************************
;
proc freq data=examdate;
table PROCID;
run;

proc freq data=examdate_2; 
table PROCID_1-PROCID_8;
run;
data cbcc.examdate_2;
set examdate_2;
run;

libname cbcc "C:\Users\jl2309\Desktop\PEDLAR\CBCC";

data examdate_2;
set cbcc.examdate_2;
run;

/* split each pair of adjacent exams into seperate datasets */
data exam_12;
set examdate_2;
keep PTID EXAMID_1 EXAMDATE_1 PROCID_1 IMP_1 FU_1 DENSITY_1 time_1 
	 EXAMID_2 EXAMDATE_2 PROCID_2 IMP_2 FU_2 DENSITY_2 time_2
	 delta_1 examtimes;
rename delta_1=delta;
run;
data exam_23;
set examdate_2;
keep PTID EXAMID_2 EXAMDATE_2 PROCID_2 IMP_2 FU_2 DENSITY_2 time_2
	 EXAMID_3 EXAMDATE_3 PROCID_3 IMP_3 FU_3 DENSITY_3 time_3
	 delta_2 examtimes;
rename EXAMID_2=EXAMID_1 EXAMDATE_2=EXAMDATE_1 PROCID_2=PROCID_1 IMP_2=IMP_1 FU_2=FU_1 DENSITY_2=DENSITY_1 time_2=time_1
	   EXAMID_3=EXAMID_2 EXAMDATE_3=EXAMDATE_2 PROCID_3=PROCID_2 IMP_3=IMP_2 FU_3=FU_2 DENSITY_3=DENSITY_2 time_3=time_2 
	   delta_2=delta;
run;
data exam_34;
set examdate_2;
keep PTID EXAMID_3 EXAMDATE_3 PROCID_3 IMP_3 FU_3 DENSITY_3 time_3 
	 EXAMID_4 EXAMDATE_4 PROCID_4 IMP_4 FU_4 DENSITY_4 time_4
	 delta_3 examtimes;
rename EXAMID_3=EXAMID_1 EXAMDATE_3=EXAMDATE_1 PROCID_3=PROCID_1 IMP_3=IMP_1 FU_3=FU_1 DENSITY_3=DENSITY_1 time_3=time_1
	   EXAMID_4=EXAMID_2 EXAMDATE_4=EXAMDATE_2 PROCID_4=PROCID_2 IMP_4=IMP_2 FU_4=FU_2 DENSITY_4=DENSITY_2 time_4=time_2 
	   delta_3=delta;
run;
data exam_45;
set examdate_2;
keep PTID EXAMID_4 EXAMDATE_4 PROCID_4 IMP_4 FU_4 DENSITY_4 time_4 
	 EXAMID_5 EXAMDATE_5 PROCID_5 IMP_5 FU_5 DENSITY_5 time_5
	 delta_4 examtimes;
rename EXAMID_4=EXAMID_1 EXAMDATE_4=EXAMDATE_1 PROCID_4=PROCID_1 IMP_4=IMP_1 FU_4=FU_1 DENSITY_4=DENSITY_1 time_4=time_1
	   EXAMID_5=EXAMID_2 EXAMDATE_5=EXAMDATE_2 PROCID_5=PROCID_2 IMP_5=IMP_2 FU_5=FU_2 DENSITY_5=DENSITY_2 time_5=time_2 
	   delta_4=delta;
run;
data exam_56;
set examdate_2;
keep PTID EXAMID_5 EXAMDATE_5 PROCID_5 IMP_5 FU_5 DENSITY_5 time_5
	 EXAMID_6 EXAMDATE_6 PROCID_6 IMP_6 FU_6 DENSITY_6 time_6
	 delta_5 examtimes;
rename EXAMID_5=EXAMID_1 EXAMDATE_5=EXAMDATE_1 PROCID_5=PROCID_1 IMP_5=IMP_1 FU_5=FU_1 DENSITY_5=DENSITY_1 time_5=time_1
	   EXAMID_6=EXAMID_2 EXAMDATE_6=EXAMDATE_2 PROCID_6=PROCID_2 IMP_6=IMP_2 FU_6=FU_2 DENSITY_6=DENSITY_2 time_6=time_2 
	   delta_5=delta;
run;
data exam_67;
set examdate_2;
keep PTID EXAMID_6 EXAMDATE_6 PROCID_6 IMP_6 FU_6 DENSITY_6 time_6 
	 EXAMID_7 EXAMDATE_7 PROCID_7 IMP_7 FU_7 DENSITY_7 time_7
	 delta_6 examtimes;
rename EXAMID_6=EXAMID_1 EXAMDATE_6=EXAMDATE_1 PROCID_6=PROCID_1 IMP_6=IMP_1 FU_6=FU_1 DENSITY_6=DENSITY_1 time_6=time_1
	   EXAMID_7=EXAMID_2 EXAMDATE_7=EXAMDATE_2 PROCID_7=PROCID_2 IMP_7=IMP_2 FU_7=FU_2 DENSITY_7=DENSITY_2 time_7=time_2 
	   delta_6=delta;
run;
data exam_78;
set examdate_2;
keep PTID EXAMID_7 EXAMDATE_7 PROCID_7 IMP_7 FU_7 DENSITY_7 time_7
	 EXAMID_8 EXAMDATE_8 PROCID_8 IMP_8 FU_8 DENSITY_8 time_8
	 delta_7 examtimes;
rename EXAMID_7=EXAMID_1 EXAMDATE_7=EXAMDATE_1 PROCID_7=PROCID_1 IMP_7=IMP_1 FU_7=FU_1 DENSITY_7=DENSITY_1 time_7=time_1
	   EXAMID_8=EXAMID_2 EXAMDATE_8=EXAMDATE_2 PROCID_8=PROCID_2 IMP_8=IMP_2 FU_8=FU_2 DENSITY_8=DENSITY_2 time_8=time_2 
	   delta_7=delta;
run;

/* set new datasets by year from 2011 to 2015*/
%macro examdur(year);
data examdur_&year.;
set exam_12(where=(year(examdate_1)=&year.))
	exam_23(where=(year(examdate_1)=&year.))
	exam_34(where=(year(examdate_1)=&year.))
	exam_45(where=(year(examdate_1)=&year.))
	exam_56(where=(year(examdate_1)=&year.))
	exam_67(where=(year(examdate_1)=&year.))
	exam_78(where=(year(examdate_1)=&year.))
	;
run;
%mend examdur;
%examdur(2011); 
%examdur(2012);
%examdur(2013);
%examdur(2014);
%examdur(2015);

proc print data=examdur_2015; run;

/* Table 1 */
%macro examvalid(year);
/* determine the duration beyond recomd or not */
data exam_&year.;
set examdur_&year.(where=(PROCID_1 in ("M-SCR" "M-SCR-B" "M-SCR-CAD" "M-SCR-D") & PROCID_1 in ("M-SCR" "M-SCR-B" "M-SCR-CAD" "M-SCR-D")));
** flup 
	0=missing (no following examination)
	1=adherence (follow up exam within or equal to recomd duration)
	2=not adh (follow up exam beyond recomd duration);
if examdate_2="" then flup=0; 
else if FU_1 in ("N" "F-12") then do;
			recomd=365;	** recommended duration is one year = 365 days;
			if delta le recomd then flup=1;
			else if delta gt recomd then flup=2;
		end;
	else if FU_1="F-6" then do;
			recomd=183; ** recommended duration is one year = 183 days;
			if delta le recomd then flup=1;
			else if delta gt recomd then flup=2;
		end;
run;

proc means data=exam_&year.(where=(FU_1 in ("N" "F-12"))) median;
var delta;
run;

proc freq data=exam_&year.(where=(FU_1 in ("N" "F-12")));
table flup;
run;

proc means data=exam_&year.(w here=(FU_1="F-6")) median;
var delta;
run;

proc freq data=exam_&year.(where=(FU_1="F-6"));
table flup;
run;

%mend examvalid;

%examvalid(2011); 
%examvalid(2012);
%examvalid(2013);
%examvalid(2014);
%examvalid(2015);


********************************************************************************;
****************     freq table examination type by times    *******************;
/*libname cbcc "C:\Users\jl2309\Desktop\PEDLAR\CBCC";*/
/**/
/*data examdate_2;*/
/*set cbcc.examdate_2;*/
/*run;*/

proc print data=examdate_2 (obs=100); run;

%MACRO freq(i);
proc freq data=examdate_2;
table PROCID_&i.*FU_&i.;
run;
%mend;

%freq(1)
%freq(2)
%freq(3)
%freq(4)
%freq(5)
%freq(6)
%freq(7)
%freq(8)

