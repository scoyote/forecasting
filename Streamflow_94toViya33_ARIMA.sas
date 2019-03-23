/*******************************************************************************/	
/****		PROC ARIMA - USGS Realtime Streamflow Data - To be compared     ****/
/****					 proc tsmodel.									 	****/
/****		Sam Croker 1/2018												****/
/*******************************************************************************/	

%include '/home/sacrok/Forecasting/forecast_macros.sas';

/* Get data from USGS NWIS API */
/* https://maps.waterdata.usgs.gov/mapper/index.html */
%loadSF(congaree,02169500,21,2017-03-01);
%loadSf(saluda,02168504,21,2017-03-01);
%loadSf(alston,02161000,21,2017-03-01);

/* Put the data together */
data AllRivers;
	merge saluda alston congaree ;
	by dte;
run;

/* prepare data - clean and aggregate to hourly data */
proc timeseries data=work.allrivers out=work.allrivers_hourly;
   id dte interval=hour
                accumulate=mean
                setmiss=median;
   var gage02161000 gage02169500;
run;

data est fcst;
	set work.allrivers_hourly;
	if datepart(dte) < input('2017-03-22',yymmdd10.) then output est;
	else output fcst;
run;

proc arima data= est;
	identify var=gage02161000; run;
	estimate p=1 q=1 ; run;
	identify var=gage02169500 crosscorr=(gage02161000) nlag=24; run;
	estimate p=3 input=( 8 $ (1)/(1 2) gage02161000 ) outest=arimaest ; run;
	forecast id=dte interval=dthour lead=24 align=beginning out=AllRivers_daily_forecast ;run;
quit;

data horizon;
	merge fcst (in=y1 keep=dte gage02169500 )
		  AllRivers_daily_forecast (in=y2 keep=dte forecast where=(DATEPART(dte) = input('2017-03-22',yymmdd10.)));
	  by dte;
	  if y1 & y2;
	  residual = forecast - gage02169500;
run;


 data _null_;
 	set horizon end=x;
 	esum+abs(residual);
 	ct+1;
 	if x then do;
 		mape=esum/ct;
 		put ct= esum= mape=;
 	end;
 run;
