
data casuser.air; set sashelp.air; run;


proc tsmodel data=casuser.air outscalars=casuser.outscalars
              outarray=casuser.outarray;
   id date interval=month;
   var air;
   outscalars mu;
   outarrays acf acov lags df acfstd pacf pacfstd iacf iacfstd;
   require tsa;
   submit;
   declare object TSA(tsa);
   rc=TSA.ACF(air, 25, lags, df, mu, acf, acfstd);
   rc=TSA.PACF(air, 25, lags, df, mu, pacf, pacfstd);
   rc=TSA.IACF(air, 25, lags, df, mu, iacf, iacfstd );
   endsubmit;
run;


ods graphics / reset width=6in height=4in imagemap;

%macro plotcfs;
	%let p1=ACF;%let p2=PACF;%let p3=IACF;
	%do cf=1 %to 3;
		title "&&p&cf";
		proc sgplot data=CASUSER.OUTARRAY nocycleattrs;
			vbar lags / response=&&p&cf stat=sum;
			vline lags / response=&&p&cf..std stat=sum y2axis;
			keylegend / location=outside;
		run;
	%end;
%mend;
%plotcfs;

ods graphics / reset;