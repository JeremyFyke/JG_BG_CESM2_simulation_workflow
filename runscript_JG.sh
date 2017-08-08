#!/bin/bash

D=$PWD

###build up CaseNames, RunDirs, Archive Dirs, etc.
    t=2
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_
    BG_Restart_Year_Short=12
    BG_Restart_Year=`printf %04d $BG_Restart_Year_Short`
    BG_Forcing_Year_Start=2
    let BG_Forcing_Year_End=BG_Restart_Year_Short-1
    
    #Set name of simulation
    CaseName=$JG_CaseName_Root"$t"
    PreviousBGCaseName="$BG_CaseName_Root""$tm1"
    JG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    BG_tm1_ArchiveDir=/glade/scratch/jfyke/$PreviousBGCaseName/run

###set project code
    ProjCode=P93300601

###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm2_0_alpha06o
    $CCSMRoot/cime/scripts/create_newcase \
                           --case $D/$CaseName \
			   --res f09_g17_gl4 \
			   --machine cheyenne \
			   --project $ProjCode \
			   --run-unsupported \
			   --user-compset \
			   --compset 1850_DATM%CRU_CLM50%BGC_CICE_POP2%ECO_MOSART_CISM2%EVOLVE_WW3_BGC%BDRD     

    #Change directories into the new experiment case directory
    cd $D/$CaseName

    ./xmlchange RUNDIR=$JG_t_RunDir
    ./xmlchange NTASKS_ATM=30
    ./xmlchange NTASKS_CPL=930
    ./xmlchange NTASKS_GLC=1440
    ./xmlchange NTASKS_ICE=300
    ./xmlchange NTASKS_LND=630
    ./xmlchange NTASKS_OCN=480
    ./xmlchange NTASKS_ROF=630
    ./xmlchange NTASKS_WAV=1

    ./xmlchange ROOTPE_ATM=930
    ./xmlchange ROOTPE_CPL=0
    ./xmlchange ROOTPE_GLC=0
    ./xmlchange ROOTPE_ICE=630
    ./xmlchange ROOTPE_LND=0
    ./xmlchange ROOTPE_OCN=960
    ./xmlchange ROOTPE_ROF=0
    ./xmlchange ROOTPE_WAV=0
    
    
    ./xmlchange RUN_TYPE='hybrid'
    ./xmlchange RUN_REFCASE="$PreviousBGCaseName"
    ./xmlchange RUN_REFDATE="$BG_Restart_Year"-01-01

    ./xmlchange DATM_MODE='CPLHISTForcing'
    ./xmlchange DATM_CPLHIST_CASE="$PreviousBGCaseName"
    ./xmlchange DATM_CPLHIST_DIR="$BG_tm1_ArchiveDir"
    
    ./xmlchange DATM_CPLHIST_YR_START=$BG_Forcing_Year_Start
    ./xmlchange DATM_CPLHIST_YR_END=$BG_Forcing_Year_End
    ./xmlchange DATM_CPLHIST_YR_ALIGN=$BG_Forcing_Year_Start

    ./xmlchange CPL_ALBAV='false'
    ./xmlchange CPL_EPBAL='off'

    ./case.setup
    
###configure archiving
    ./xmlchange DOUT_S=FALSE
    
###configure CISM2    
    echo 'ice_tstep_multiply=10' >> user_nl_cism
    
###configure POP
    #Turn off precipitation scaling in POP for JG runs
    echo ladjust_precip=.false. > user_nl_pop       
    
###concatenate monthly forcing files to expected location
    
    for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do 
	for m in `seq -f '%02g' 1 12`; do
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do       
	      fname_out=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m.nc
	      if [ -f $fname_out ]; then
	         echo 'NOT Concatenating ' $fname_out ': already exists.'
	      else
	         echo 'Concatenating ' $fname_out
	         ncrcat -O $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc $fname_out &
              fi
	   done
	   wait
	   for ftype in ha2x1hi ha2x1h ha2x3h ha2x1d; do
	       for fname in $BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.$ftype.$yr-$m-*.nc; do 
	           if [ -e "%fname" ]; then
	               rm -v $fname
                   fi
	       done
	   done	   
	done
    done    

###configure datm streams
    #Maybe nothing to do here..?

####copy over JG restart files from previous BG run
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cice.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cism.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.clm2.r."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.clm2.rh0."$BG_Restart_Year"-01-01-00000.nc;    cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.hi."$BG_Restart_Year"-01-01-00000.nc;      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.cpl.r."$BG_Restart_Year"-01-01-00000.nc;       cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.mosart.r."$BG_Restart_Year"-01-01-00000.nc;    cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.mosart.rh0."$BG_Restart_Year"-01-01-00000.nc;  cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }     
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.r."$BG_Restart_Year"-01-01-00000.nc;       cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.ro."$BG_Restart_Year"-01-01-00000;         cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }        
    f=$BG_tm1_ArchiveDir/rpointer.drv;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.glc;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ice;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.lnd;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ocn.ovf;                                                  cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.ocn.restart;                                              cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_ArchiveDir/rpointer.rof;                                                      cp -uvf $f $JG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  
    #Ensure dates are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$BG_Restart_Year"-01-01-00000/g" "$BG_tm1_ArchiveDir"/rpointer.*

###configure submission length, diagnostic CPL history output, and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1
    ./xmlchange RESUBMIT=149
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='00:45'
    ./xmlchange PROJECT="$ProjCode"

###make some soft links for convenience 
    ln -svf $JG_t_RunDir RunDir
    ln -svf /glade/scratch/jfyke/archive/$CaseName ArchiveDir
    
###set up restoring
    for m in `seq -f '%02g' 1 12`; do
      echo 'Calculating monthly restoring SSS climatology for month: ' $m
      flist=""
      for yr in `seq -f '%04g' $BG_Forcing_Year_Start $BG_Forcing_Year_End`; do
	flist="$flist $BG_tm1_ArchiveDir/$PreviousBGCaseName.pop.h.$yr-$m.nc"
      done    
      ncra -F -v SALT -d z_t,1,1,1 $flist $BG_tm1_ArchiveDir/SSS_FLXIO_$m.nc
      ncra -A -F -v SALT_F $flist $BG_tm1_ArchiveDir/SSS_FLXIO_$m.nc
    done

    ncrcat -O $BG_tm1_ArchiveDir/SSS_FLXIO_* $BG_tm1_ArchiveDir/temp.nc
    ncrename -v SALT,SSS $BG_tm1_ArchiveDir/temp.nc
    ncrename -v SALT_F,FLXIO $BG_tm1_ArchiveDir/temp.nc
    ncwa -O -a z_t $BG_tm1_ArchiveDir/temp.nc $BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc
    rm $BG_tm1_ArchiveDir/SSS_FLXIO_* $BG_tm1_ArchiveDir/temp.nc

    if [ ! -f $BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc ]; then
      echo 'Error: something wrong with climo_SSS_FLXIO.nc creation'
      exit
    fi
    
    echo "sfwf_filename='$BG_tm1_ArchiveDir/climo_SSS_FLXIO.nc'" >> user_nl_pop
    echo "sfwf_file_fmt='nc'" >> user_nl_pop
    echo "sfwf_data_type='monthly'" >> user_nl_pop    
    
###build
    ./case.build    

###sumbmit
    #./case.submit


    
