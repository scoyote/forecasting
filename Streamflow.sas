
/* Note on USGS - not all sites have 15 minute data. Please check before merging*/

/* raw filename statments, typical of what is constructed by macro 
filename congcola url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02169500&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename saluda url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02168504&period=31&begin_date=2017-12-01&end_date=2017-12-31';
filename alston url 'https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02161000&period=31&begin_date=2017-12-01&end_date=2017-12-31';
*/


%macro loadSf(ds,siteno,period,begindate);
	filename _ftemp url "%nrstr(https://waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=)&siteno%nrstr(&begin_date=)&begindate%nrstr(&period)=&period";

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
	proc sql; 
		drop table t_flow;
		drop table t_gage;
	quit;
%mend;

%macro CombineRivers(r_ds);
	data allrivers;
		merge &r_ds;
		by dte;
	run;
	


%mend CombineRivers;

%loadSF(congaree,02169500,31,2017-12-01);
%loadSf(saluda,02168504,31,2017-12-01);
%loadSf(alston,02161000,31,2017-12-01);

%combinerivers(r_ds=congaree saluda alston);

data AllRivers;
	merge alston (in=alst) congaree (in=cong) saluda (in=salu);
	by dte;
	*if alst and cong and salu;
run;

proc sort data=WORK.ALLRIVERS out=Work.preProcessedData;
	by dte;
run;

proc timeseries data=Work.preProcessedData seasonality=24 plots=(series spectrum corr) crossplots=(series ccf);
	id dte interval=hour;
	var Gage02169500 / accumulate=average transform=none dif=0 sdif=0;
	crossvar Gage02161000 / accumulate=average transform=none dif=0 sdif=0;
	crossvar Gage02168504 / accumulate=average transform=none dif=0 sdif=0;
	crosscorr / nlag=16;
	spectra / domain=frequency;
run; 

proc delete data=Work.preProcessedData;
run;


cas; 
caslib _all_ assign;

proc casutil;
	load data=work.allrivers 
	outcaslib="casuser"
	casout="allriversM";
run;

