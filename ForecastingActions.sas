cas;




proc cas;
	builtins.defineActionset / name = "USGSUtility"
		actions={
			{ /* first action */
				name='pullsite'
				description='given a site and date range, pull streamflow and gauge'
				parms={
					{name='caslib' type='string' required=TRUE}
					{name='table' type='string' required=TRUE}
				}
				definition="
					table.tableInfo result=a / caslib=caslib table=table;
					send_response(a);	
				"
			}
			{ /* second action */
				name='ddstep'
				description='given a site and date range, pull streamflow and gauge'
				parms={
					{name='caslib' type='string' required=TRUE}
					{name='table' type='string' required=TRUE}
				}
				definition="
						filename _ftemp url ""%nrstr(https://nwis.waterdata.usgs.gov/sc/nwis/uv?cb_00060=on&cb_00065=on&format=rdb&site_no=02169500&begin_date=2017-03-01&
       end_date=2017-03-22)"";
						data caslib.table;
							infile _ftemp dlm = '09'x dsd;
							input @1 agency_cd $ @;
							if agency_cd = 'USGS' then do;
							input @6 site_no $ @15 dte anydtdtm16. @32 tz_cd $ discharge discharge_cd $ gageheight gageheight_cd $;
								output;
							end;
							format dte datetime.;
							keep site_no dte discharge gageheight;
						run;  
						
						filename _ftemp clear;	
				"
			}
		};
quit;
