#!/bin/bash

###TO DO NOTES###
#-Update ice sheet model
#-Ensure working topography updating with new version
#-trim output fields where possible
D=$PWD

    t=4
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0012
    JG_Restart_Year=0076

    CaseName=$BG_CaseName_Root"$t"
    PreviousJGCaseName=$JG_CaseName_Root"$t" #Need previous JG iteration to exist, of same iteration number as planned BG
    PreviousBGCaseName="$BG_CaseName_Root""$tm1" #Need previous BG iteration to exist, of n-1 iteration number as planned BG
       
    BG_t_RunDir=/glade/scratch/jfyke/$CaseName/run
    JG_t_RunDir=/glade/scratch/jfyke/$PreviousJGCaseName/run
    BG_tm1_RunDir=/glade/scratch/jfyke/$PreviousBGCaseName/run

###set project code
    ProjCode=P93300601

###set up model
    #Set the source code from which to build model
    CCSMRoot=/glade/u/home/jfyke/work/CESM_model_versions/cesm2_0_alpha06o
    $CCSMRoot/cime/scripts/create_newcase \
                           --case $D/$CaseName \
			   --res f09_g17_gl4 \
			   --mach cheyenne \
			   --project $ProjCode \
			   --run-unsupported \
			   --user-compset \
			   --compset 1850_CAM60_CLM50%BGC_CICE_POP2%ECO_MOSART_CISM2%EVOLVE_WW3_BGC%BDRD

    #Change directories into the new experiment case directory
    cd $D/$CaseName

    NTHRDS=1
    PES_PER_NODE=36
    MAX_TASKS_PER_NODE=36

    NTASKS_ATM=50*$PES_PER_NODE
    NTHRDS_ATM=$NTHRDS
    ROOTPE_ATM=0

    NTASKS_GLC=$NTASKS_ATM
    NTHRDS_GLC=$NTHRDS
    ROOTPE_GLC=0

    NTASKS_LND=39*$PES_PER_NODE
    NTHRDS_LND=$NTHRDS
    ROOTPE_LND=0

    NTASKS_ROF=$NTASKS_LND
    NTHRDS_ROF=$NTHRDS
    ROOTPE_ROF=$ROOTPE_LND

    NTASKS_ICE=10*$PES_PER_NODE
    NTHRDS_ICE=$NTHRDS
    ROOTPE_ICE=$NTASKS_LND

    NTASKS_CPL=$NTASKS_ICE
    NTHRDS_CPL=$NTHRDS
    ROOTPE_CPL=$NTASKS_LND

    NTASKS_WAV=1*$PES_PER_NODE
    NTHRDS_WAV=$NTHRDS
    ROOTPE_WAV=$NTASKS_LND+$NTASKS_ICE

    NTASKS_OCN=10*$PES_PER_NODE
    NTHRDS_OCN=$NTHRDS
    ROOTPE_OCN=$NTASKS_ATM
    
    ./xmlchange NTASKS_ATM=$NTASKS_ATM
    ./xmlchange NTHRDS_ATM=$NTHRDS_ATM
    ./xmlchange ROOTPE_ATM=$ROOTPE_ATM

    ./xmlchange NTASKS_GLC=$NTASKS_GLC
    ./xmlchange NTHRDS_GLC=$NTHRDS_GLC
    ./xmlchange ROOTPE_GLC=$ROOTPE_GLC

    ./xmlchange NTASKS_LND=$NTASKS_LND
    ./xmlchange NTHRDS_LND=$NTHRDS_LND
    ./xmlchange ROOTPE_LND=$ROOTPE_LND

    ./xmlchange NTASKS_ROF=$NTASKS_ROF
    ./xmlchange NTHRDS_ROF=$NTHRDS_ROF
    ./xmlchange ROOTPE_ROF=$ROOTPE_ROF

    ./xmlchange NTASKS_ICE=$NTASKS_ICE
    ./xmlchange NTHRDS_ICE=$NTHRDS_ICE
    ./xmlchange ROOTPE_ICE=$ROOTPE_ICE

    ./xmlchange NTASKS_CPL=$NTASKS_CPL
    ./xmlchange NTHRDS_CPL=$NTHRDS_CPL
    ./xmlchange ROOTPE_CPL=$ROOTPE_CPL

    ./xmlchange NTASKS_WAV=$NTASKS_WAV
    ./xmlchange NTHRDS_WAV=$NTHRDS_WAV
    ./xmlchange ROOTPE_WAV=$ROOTPE_WAV

    ./xmlchange NTASKS_OCN=$NTASKS_OCN
    ./xmlchange NTHRDS_OCN=$NTHRDS_OCN
    ./xmlchange ROOTPE_OCN=$ROOTPE_OCN

    ./xmlchange PES_PER_NODE=$PES_PER_NODE
    ./xmlchange MAX_TASKS_PER_NODE=$MAX_TASKS_PER_NODE


###customize PE layout

###set up case    
    ./xmlchange RUN_TYPE='hybrid'
    #Set primary restart-gathering names
    ./xmlchange RUN_REFCASE=$PreviousJGCaseName
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01  
    ./case.setup

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir   

###enable custom coupler output
    echo 'histaux_a2x3hr = .true.' > user_nl_cpl
    echo 'histaux_a2x24hr = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hri = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hr = .true.' >> user_nl_cpl
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1

###configure topography updating

     CAM_topo_regen_dir=$BG_t_RunDir/dynamic_atm_topog
     
     #Marcus-recommended module loads
     module purge
     module load ncarenv/1.2
     module load intel/17.0.1
     module load ncarcompilers/0.4.1
     module load mpt/2.15f

     module load netcdf/4.4.1.1
     module load nco/4.6.2
     module load python/2.7.13     
     
     if [ ! -d $CAM_topo_regen_dir ]; then
       echo 'Checking out and building topography updater...'

       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
       svn co --quiet $trunk $CAM_topo_regen_dir
       
       source $CAM_topo_regen_dir/setup.sh --rundir $BG_t_RunDir --project "$ProjCode" --walltime 00:45:00 --queue regular       
       
       cd $CAM_topo_regen_dir/bin_to_cube
       gmake --quiet
       cd $CAM_topo_regen_dir/cube_to_target
       gmake --quiet
 
       cd $D/$CaseName
 
       data_assimilation_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
       ./xmlchange DATA_ASSIMILATION=TRUE
       ./xmlchange DATA_ASSIMILATION_CYCLES=1
       ./xmlchange DATA_ASSIMILATION_SCRIPT=$data_assimilation_script

      fi       

###configure archiving
    ./xmlchange DOUT_S=FALSE

###copy all but CAM restarts over from end of JG simulation, and CAM restarts from previous BG simulation
    
    f=$JG_t_RunDir/$PreviousJGCaseName.cice.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cism.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.r."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.clm2.rh0."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.hi."$JG_Restart_Year"-01-01-00000.nc;      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.cpl.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.datm.rs1."$JG_Restart_Year"-01-01-00000.bin;   cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.r."$JG_Restart_Year"-01-01-00000.nc;    cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$JG_t_RunDir/$PreviousJGCaseName.mosart.rh0."$JG_Restart_Year"-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }     
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.r."$JG_Restart_Year"-01-01-00000.nc;       cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/$PreviousJGCaseName.pop.ro."$JG_Restart_Year"-01-01-00000;         cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }        
    f=$JG_t_RunDir/rpointer.drv;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.glc;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ice;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.lnd;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.ovf;                                                  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.ocn.restart;                                              cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$JG_t_RunDir/rpointer.rof;                                                      cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }

    #Ensure dates of non-CAM restart pointers are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$JG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.*

    #Then copy over CAM restarts
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.rs.$BG_Restart_Year-01-01-00000.nc; cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/rpointer.atm;                                               cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  

###set component-specific restarting tweaks that aren't handled by default
    #CAM
    #overwrite default script-generated restart info with custom values, to represent the migrated CAM restart file
	echo "bnd_topo='$BG_t_RunDir/topoDataset.nc'" > user_nl_cam
        echo "ncdata='$BG_t_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc'" >> user_nl_cam

#Jer: if Marcus's updates to topography updater work, then the following lines can be removed.
    #for a hybrid run, tack on landm_coslat, landfrac to cam.r. (since this is being used as the topography file)
#    DataSourceFile=/glade/p/cesmdata/cseg/inputdata/atm/cam/topo/fv_0.9x1.25_nc3000_Nsw042_Nrs008_Co060_Fi001_ZR_sgh30_24km_GRNL_c170103.nc
#    ncks -A -v LANDM_COSLAT,LANDFRAC,\
#TERR_UF,\
#SGH_UF,\
#GBXAR,\
#MXDIS,\
#RISEQ,\
#FALLQ,\
#MXVRX,\
#MXVRY,\
#ANGLL,\
#ANGLX,\
#ANISO,\
#ANIXY,\
#HWDTH,\
#WGHTS,\
#CLNGT,\
#CWGHT,\
#COUNT $DataSourceFile $BG_t_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc
	
    #Ensure dates are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$BG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.atm
    
###configure submission length and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange RESUBMIT=34
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='02:00:00'
    ./xmlchange PROJECT="$ProjCode"   

#####run dynamic topography interactively update to bring CAM topography up to JG-generated topography before starting
    if [ ! -f $BG_t_RunDir/Temporary_output_file.nc ]; then #Presence of this file signifies an already-run topography updating in this new BG directory...so, skip
       echo 'Submitting an initial topography updating job.  Specified 45 minute sleep of this script will ensue.'
       cd $CAM_topo_regen_dir
       ./submit_topo_regen_script.sh
       cd $D/$CaseName
       sleep 45m
    fi

####build
    ./case.build
####submit
    ./case.submit


