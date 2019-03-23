
%include '/home/sacrok/Forecasting/forecast_macros.sas';
/* Connect to CAS - Start new session */
cas ;
/* assign CAS libnames */
caslib _all_ assign;

%include '/home/sacrok/Forecasting/forecast_macros.sas';

/* Load Data https://maps.waterdata.usgs.gov/mapper/index.html */
%CASLoadNWIS(casuser,alston,02161000,21,2017-03-01);
%CASLoadNWIS(casuser,congaree,02169500,21,2017-03-01);

data casuser.AllRivers;
	merge casuser.alston casuser.congaree ;
	by dte;
run;

/* prepare data - clean and aggregate to hourly data */
proc cas;
	timeData.runTimeCode / 
		table={name='ALLRIVERS', caslib='CASUSER(sacrok)'}, 
		timeId={name='dte'}, 
		interval='HOUR', 
	    casOut={name='ALLRIVERS_HOURLY', caslib='Public'}, 
	    series={{name='GAGE02161000', 
				 accumulate='AVG', 
	       		 setMiss='MEDIAN'}, 
	       		{name='GAGE02169500', 
	       		 accumulate='AVG', 
	       		 setMiss='MEDIAN'}},
	    code='',
    	;
quit;

/* proc casutil; */
/*    droptable casdata="allrivers_hourly" incaslib="public" quiet; */
/* run; */
proc casutil incaslib="public" outcaslib="public";                         /* 2 */
   promote casdata="allrivers_hourly";
quit;

/* plot the ACF, PACF, IACF and CCF for two variables */
%plotXCF(public,allrivers_hourly,gage02169500,gage02161000,25,dte,hour);


/* build transfer function model */
proc tsmodel 
        data=public.allrivers_hourly
    	outobj=(
    	streamFor=casuser.my_for
    	streamEst=casuser.my_est
    	)
    	;
    
    id dte interval=hour;
    var gage02161000 gage02169500;
    require tsm;
    submit;

     declare object streamModel(tsm);
     declare object streamSpec(arimaspec);
     declare object streamEst(tsmpest);
     declare object streamFor(tsmfor);
    
     /* holder arrays for ARIMA and Transfer Function Parameters */
     array num[1]/nosymbols;
     array den[2]/nosymbols;
     array ar[3]/nosymbols;

     rc = streamSpec.Open( );
     *** Specify AR orders: p = (1 2 3)  ***;
     ar[1] = 1;
     ar[2] = 2;
     ar[3] = 3;
     rc = streamSpec.AddARPoly(ar);
     
	 /* add transfer function specification */
     rc = streamSpec.AddTF('gage02161000', 8); 
     num[1] = 1;
     rc = streamSpec.AddTFNumPoly('gage02161000', num);
     den[1] = 1;
     den[2] = 2;
     rc = streamSpec.AddTFDenPoly('gage02161000', den);
       
     rc = streamSpec.Close( );

     *** setup and run the TSM object ***;
     rc = streamModel.Initialize(streamSpec);
     rc = streamModel.SetY(gage02169500);
     rc = streamModel.SetOption('lead',24);
     rc = streamModel.SetOption('back',24);
     rc = 
     rc = streamModel.AddX(gage02161000);
     rc = streamModel.Run( );

     *** output Airline Model forecasts and estimates ***;
     
     rc = streamFor.Collect(streamModel);
     rc = streamEst.Collect(streamModel);
        
  endsubmit;
 quit;
 
 proc print data=casuser.my_est noobs label;
 	var _parm_ _est_;
 run;
 data _null_;
 	set casuser.my_for end=x;
 	where error <> .;
 	if DATEPART(dte) = input('2017-03-22',yymmdd10.) then do;
	 	esum+abs(error);
	 	ct+1; 

	 end;
	 else do;
	 	ossum+abs(error);
	 	ctx+1;
	 end;
	 if x then do;
	 		mape=esum/ct;
	 		mape2=ossum/ctx;
	 		put ct= esum= mape= mape2=;
	 end;
 run;





