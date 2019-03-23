cas; 
caslib _all_ assign;

proc timeseries data=work.allrivers out=Public.allrivers_hourly (promote=yes)
                plots=  (acf pacf iacf  ) crossplots=all;
   id dte interval=hour
                accumulate=mean
                setmiss=median;
   var gage02169500  / accumulate=mean setmissing=median;
   crossvar gage02161000 / accumulate=mean setmissing=median ;
run;

proc sort data =public.allrivers_hourly out= work.allrivers_local;
by dte;
run;

proc hpfevents data=work.allrivers_local lead=24; 
	id dte interval=hour;
eventdef flooded='03jan17:06:00'dt;
eventdata out=public.Rivers_eventds (label='Event List'); 
run;


proc casutil;
promote casdata='rivers_eventds' incaslib='public'  casout='rivers_eventds';
quit;