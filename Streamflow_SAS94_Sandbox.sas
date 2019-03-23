
%include '/home/sacrok/Forecasting/forecast_macros.sas';

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
                plots=  (acf pacf iacf  ) crossplots=all;
   id dte interval=hour
                accumulate=mean
                setmiss=median;
   var gage02169500  / accumulate=mean setmissing=median;
   crossvar gage02161000 / accumulate=mean setmissing=median ;
run;

proc arima data= allrivers_hourly;
	identify var=gage02161000(1)  stationarity=(adf=0) scan esacf; run;
	estimate p=1 q=1 ml; run;
	identify var=gage02169500(1) crosscorr=(gage02161000(1)) nlag=24 scan esacf stationarity=(adf=0); run;

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