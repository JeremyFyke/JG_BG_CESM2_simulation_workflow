#!/bin/bash

###NOTES###
#Additional fields being added from topo init file at present, probably because topography updater isn't working.  When latter is fixed, remove these fields

D=$PWD

    t=2
    let tm1=t-1

    BG_CaseName_Root=BG_iteration_get_topog_updater_working_
    JG_CaseName_Root=JG_iteration_

    BG_Restart_Year=0012
    JG_Restart_Year=0011

    CaseName=$BG_CaseName_Root"$t"
    PreviousJGCaseName=$JG_CaseName_Root"$t"
    PreviousBGCaseName=BG_iteration_"$tm1"
       
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

###customize PE layout

###set up case    
    ./xmlchange RUN_TYPE='hybrid'
    #Set primary restart-gathering names
    ./xmlchange RUN_REFCASE=$PreviousJGCaseName
    ./xmlchange RUN_REFDATE="$JG_Restart_Year"-01-01  
    ./case.setup
   
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
       
       source $CAM_topo_regen_dir/setup.sh -r $BG_t_RunDir -p "$ProjCode" -w 00:30:00
       
       #gmake=/usr/bin/gmake
       #gmake=gmake       
       
       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
       svn co $trunk $CAM_topo_regen_dir
       cd $CAM_topo_regen_dir/bin_to_cube
       gmake
       cd $CAM_topo_regen_dir/cube_to_target
       gmake
 
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

    #Ensure dates of non-CAM restarts are correct (can be wrong if year previous to final year of JG run is used)
    sed -i "s/[0-9]\{4\}-01-01-00000/"$JG_Restart_Year"-01-01-00000/g" $BG_t_RunDir/rpointer.*

    #Then copy over CAM restarts
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.r.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.rs.$BG_Restart_Year-01-01-00000.nc; cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }    
    f=$BG_tm1_RunDir/$PreviousBGCaseName.cam.i.$BG_Restart_Year-01-01-00000.nc;  cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }
    f=$BG_tm1_RunDir/rpointer.atm;                                               cp -vf $f $BG_t_RunDir || { echo "copy of $f failed" ; exit 1; }  

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir

####run dynamic topography interactively update to bring CAM topography up to JG-generated topography before starting
    cd $CAM_topo_regen_dir
    export RUNDIR=$BG_t_RunDir
    ./CAM_topo_regen.sh
    cd $D/$CaseName



