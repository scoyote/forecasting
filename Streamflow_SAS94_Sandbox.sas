
/* Note on USGS - not all sites have 15 minute data. Please check before merging*/

/* raw filename statments, typical of what is constructed by macro 
filename congcola url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02169500&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename saluda url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02168504&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename alston url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02161000&period=31&begin_date=2017-12-01&end_date=2017-12-31';
*/
	
%macro loadSf(ds,siteno,period,begindate);
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
%mend;

/* Get data from USGS NWIS API */
%loadSF(congaree,02169500,21,2017-03-01);
%loadSf(saluda,02168504,21,2017-03-01);
%loadSf(alston,02161000,21,2017-03-01);

/* Put the data together */
data AllRivers;
	merge saluda alston congaree ;
	by dte;
run;

proc timeseries data=work.allrivers out=work.allrivers_hourly 
                plots=all ;
   id dte interval=hour
                accumulate=mean
                setmiss=median;
   var gage02161000 gage02169500;
run;

proc arima data= allrivers_hourly;
	identify var=gage02161000   ; run;
	estimate p=1 q=1 ml; run;
	identify var=gage02169500 crosscorr=(gage02161000) nlag=24; run;
/* 	estimate input=( 10 $ (1)/(1,2) gage02161000 ); run; */
	estimate p=3 input=( 8 $ (1 2)/(1 2) gage02161000 ) outest=arimaest ml; run;
	forecast id=dte interval=dthour back=24 lead=24 align=beginning out=AllRivers_daily_forecast ;run;
quit;


proc spectra data=work.allrivers_hourly out=spect p s adjmean whitetest;
var gage02169500 ;
run;
   proc sgplot data=spect ;
      where period < 50;
      series x=period y=p_01 / markers markerattrs=(symbol=circlefilled);
      refline 11 / axis=x;
   run;