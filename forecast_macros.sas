/* Utilitiy macros related to forecasting with TSmodel */
/***************************************************************/
/*****  CASLoadNWIS Macro								   *****/
/*****	Reaches out to the USGS NWIS REST utility to       *****/
/*****  gather a tab (sortof) delimited file containing    *****/
/*****  observations of stream gage(sic) height and        *****/
/*****  discharge. Resulting table is a prepared table     *****/
/*****  that is ready to analyze. Time series aggregation  *****/
/*****  is not been done.							       *****/
/***************************************************************/
%macro CASLoadNWIS(
		caslib,		/* caslib to save resulitng table */
		castable,	/* table name for resulting table */
		siteno,		/* USGS NWS site number */
		period,		/* number of days to extract */
		begindate	/* beginning date of extract */
		);
	data _null_;
		call symput('enddate',put(intnx('day',input("&begindate",anydtdte10.),&period),yymmdd10.));
	run;
	%let nwisAPIEndpoint="%nrstr(https://nwis.waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=)&siteno%nrstr(&begin_date=)&begindate%nrstr(&end_date)=&enddate";
	%put NOTE: Loading data from NWIS via API...;
	%put CASLIB       = &CASLIB;
	%put CASTable     = &castable;
	%put NWIS Siteno  = &siteno;
	%put Period       = &period;
	%put Begin Date   = &begindate;
	%put API Endpoint: &nwisAPIEndpoint;
	
	filename _ftemp url &nwisAPIEndpoint;
	data &caslib..&castable;
		infile _ftemp dlm = '09'x dsd;
		input @1 agency_cd $ @;
		if agency_cd = 'USGS' then do;
/* 			this mixed input fixed some inconsistency in the tab delimiting that I did not research  */
			input @6 site_no $ @15 dte anydtdtm16. @32 tz_cd $ discharge discharge_cd $ gageheight gageheight_cd $;
			output;
		end;
		format dte datetime.;
		keep site_no dte discharge gageheight;
	run;  
	
	filename _ftemp clear;
	
	proc cas;
		transpose.transpose /                                         
	   		table={caslib="&caslib" name="&castable", groupby={"dte"}},   
	   		attributes={{name="site_no", label="SiteNo"}},              
	   		transpose={"gageheight"},   
	   		prefix='GAGE',                              
	   		id={"site_no"},  
	   		casOut={caslib="&caslib" name="t_gage", replace=true}  ;                  
		run;
		transpose.transpose /                                         
	   		table={caslib="&caslib" name="&castable", groupby={"dte"}}   
	   		attributes={{name="site_no", label="SiteNo"}} 
	   		transpose={"discharge"}          
	   		prefix='FLOW'                       
	   		id={"site_no"}
	   		casOut={caslib="&caslib" name="t_flow", replace=true}  ;  
	   	run;
	quit;
	data &caslib..&castable;
		merge &caslib..t_gage (in=gage) &caslib..t_flow (in=flow);
		by dte;
		if gage and flow;
		drop _name_;
	run;
	proc casutil;
		droptable casdata= "t_flow" incaslib="casuser";
		droptable casdata= "t_gage" incaslib="casuser";
	quit;
%mend CASLoadNWIS;


/***************************************************************/
/*****  plotXCF Macro 									   *****/
/*****	Plots the acf,pacf,iacf and ccf for two varialbes  *****/
/***************************************************************/
%macro plotXCF(
		tscaslib,	/* caslib for ts table*/
		tsdata,		/* dataset of prepared time series */
		tsvar,		/* analysis variable */
		tsxvar,	 	/* cross correlation varible */
		numlag,		/* number of lags to calculate */
		idvar,		/* time series datetime id variable */
		tsint		/* time series interval */
		);
	proc tsmodel data=&tscaslib..&tsdata 
					outscalar=casuser.outscalars
	              	outarray=casuser.outarray;
	   id &idvar interval=&tsint;
	   var &tsvar &tsxvar;
	   outscalars mu;
	   outarrays 
	   acf acov lags df acfstd 
	   pacf pacfstd iacf iacfstd 
	   acfx acfxstd pacfx pacfxstd iacfx iacfxstd ;
	   require tsa;
	   submit;
	   declare object TSA(tsa);
	   rc=TSA.ACF(&tsvar, &numlag, lags, df, mu, acf, acfstd);
	   rc=TSA.PACF(&tsvar, &numlag, lags, df, mu, pacf, pacfstd);
	   rc=TSA.IACF(&tsvar, &numlag, lags, df, mu, iacf, iacfstd );

	   rc=TSA.ACF(&tsxvar, &numlag, lags, df, mu, acfx, acfxstd);
	   rc=TSA.PACF(&tsxvar, &numlag, lags, df, mu, pacfx, pacfxstd);
	   rc=TSA.IACF(&tsxvar, &numlag, lags, df, mu, iacfx, iacfxstd );
	   
	   endsubmit;
	run;
	
	proc tsmodel data=&tscaslib..&tsdata 
					outscalar=casuser.outscalarsccf
	              	outarray=casuser.outarrayccf;
	   id &idvar interval=&tsint;
	   var &tsvar &tsxvar;
	   outscalars ymu xmu;
	   outarrays lags df ccov ccf ccfstd ccf2std ccfnorm ccfprob ccflprob;;
	   require tsa;
	   submit;
	   declare object TSA(tsa);

	   rc=TSA.CCF(&tsvar,&tsxvar, &numlag, lags, df, xmu, ymu, ccf, ccfstd,ccf2std, ccfnorm, ccfprob, ccflprob );
	   
	   endsubmit;
	run;
	

	%let p1=ACF;%let p2=PACF;%let p3=IACF;%let p4=ACFX; %let p5=PACFX; %let p6=IACFX;
	%do cf=1 %to 6;
		title "&&p&cf";
		ods graphics / reset width=6in height=4in imagemap;
		proc sgplot data= casuser.outarray nocycleattrs;
			vbar lags / response=&&p&cf stat=sum;
			vline lags / response=&&p&cf..std stat=sum y2axis;
			keylegend / location=outside;
		run;
		ods graphics / reset;
	%end;
	
	ods graphics / reset width=6in height=4in imagemap;
	title "CCF";
	proc sgplot data= casuser.outarrayccf nocycleattrs;
		vbar lags / response=ccfprob stat=sum;
		vline lags / response=ccfstd stat=sum y2axis;
		keylegend / location=outside;
	run;
	ods graphics / reset
%mend plotXCF;



/***************************************************************/
/*****  loadSF Macro									   *****/
/*****	Like the CAS enabled CASLoadNWIS macro but using   *****/
/*****  SAS 9.4 tools only								   *****/
/***************************************************************/
/* Note on USGS - not all sites have 15 minute data. Please check before merging*/

/* raw filename statments, typical of what is constructed by macro 
filename congcola url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02169500&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename saluda url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02168504&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename alston url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02161000&period=31&begin_date=2017-12-01&end_date=2017-12-31';
*/
/* This macro retrieves a period of data for gage 000060 and flow 00065 for appropriate  */
/*    USGS NWIS sites. At this time it is up to the user to ensure that they are loaded */
/*    correctly.  */
%macro loadSf(
		ds,			/* resulting dataset name */
		siteno,		/* USGS NWIS site number */
		period,		/* Number of days to extract */
		begindate); /* date to start extract */
	* calculate the enddate for the rest query;	
	data _null_;
		call symput('enddate',put(intnx('day',input("&begindate",anydtdte10.),&period),yymmdd10.));
	run;
	filename _ftemp url "%nrstr(https://nwis.waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=)&siteno%nrstr(&begin_date=)&begindate%nrstr(&end_date)=&enddate";

	data &ds;
		infile _ftemp dlm = '09'x dsd;
		input @1 agency_cd $ @;
		if agency_cd = 'USGS' then do;
			/* this mixed input fixed some inconsistency in the tab delimiting that I did not research */ 
			input @6 site_no $ @15 dte anydtdtm16. @32 tz_cd $ discharge discharge_cd $ gageheight gageheight_cd $;
			output;
		end;
		format dte datetime.;
		keep site_no dte discharge gageheight;
	run;  
	filename _ftemp clear;
	
	proc transpose data=&ds out=t_gage prefix=Gage
			label=_Label_;
		var  gageheight;
		id site_no;
		idlabel site_no;
		by dte;
		drop _name_;
	run;
	proc transpose data=&ds out=t_flow prefix=Flow
			label=_Label_;
		var  discharge;
		id site_no;
		idlabel site_no;
		by dte;
		drop _name_;
	run;
	data &ds;
		merge t_gage (in=gage) t_flow (in=flow);
		by dte;
		if gage and flow;
		drop _name_;
	run;
/* 	proc sql;  */
/* 		drop table t_flow; */
/* 		drop table t_gage; */
/* 	quit; */
%mend loadSf;
