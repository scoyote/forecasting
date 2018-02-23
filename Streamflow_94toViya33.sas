

/* cas;  */
/* caslib _all_ assign; */

%macro CASLoadNWIS(caslib,castable,siteno,period,begindate);
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


%CASLoadNWIS(casuser,alston,02161000,21,2017-03-01);
%CASLoadNWIS(casuser,congaree,02169500,21,2017-03-01);

data casuser.AllRivers;
	merge casuser.alston casuser.congaree ;
	by dte;
run;


/* proc tsmodel data= casuser.allrivers */
/*              out = public.allrivers_hourly; */
/*     id dte interval=hour; */
/*     var gage02161000 gage02169500 /accumulate=mean setmiss=median; */
/*      */
/* run; */

proc cas;
	timeData.runTimeCode / 
		table={name='ALLRIVERS', caslib='CASUSER(sacrok)'}, 
		timeId={name='dte'}, 
		interval='HOUR', 
	    casOut={name='ALLRIVERS_HOURLY', caslib='Public', replace=true}, 
	    series={{name='GAGE02161000', 
				 accumulate='AVG', 
	       		 setMiss='MEDIAN'}, 
	       		{name='GAGE02169500', 
	       		 accumulate='AVG', 
	       		 setMiss='MEDIAN'}},
	    code='',
    	;
quit;

/* proc casutil ;                          */
/*    promote  casdata="allrivers_hourly" incaslib='public' ; */
/* quit; */

/* http://go.documentation.sas.com/?cdcId=vdmmlcdc&cdcVersion=8.11&docsetId=castsp&docsetTarget=castsp_tsm_sect097.htm&locale=en */

ods graphics on;
proc tsmodel 
        data=public.allrivers_hourly
    	outobj=(
    	streamFor=casuser.my_for
    	streamEst=casuser.my_est)
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
     rc = streamSpec.AddTF('gage02161000', 10); * delay=10;
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





