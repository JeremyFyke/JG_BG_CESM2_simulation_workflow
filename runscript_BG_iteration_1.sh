#!/bin/bash

D=$PWD

t=1
BG_CaseName_Root=BG_iteration_
CaseName="$BG_CaseName_Root""$t"

BG_t_RunDir=/glade/scratch/jfyke/$CaseName/run

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
			   --compset 1850_CAM60_CLM50%BGC_CICE_POP2%ECO_MOSART_CISM2%EVOLVE_WW3_BGC%BDRD \

    #Change directories into the new experiment case directory
    cd $D/$CaseName

###customize PE layout

###set up case
    ./case.setup

###configure initial restart load from previous CESM/CISM simulations
   #This first iteration is different from subsequent JG/BG iteration procedure.
   #./xmlchange RUN_TYPE='hybrid'
   #./xmlchange RUN_REFCASE='b.e20.B1850.f09_g17.pi_control.all.149.cism'
   #./xmlchange RUN_REFDATE=0103-01-01
   #./xmlchange RUN_STARTDATE=0001-01-01
   #cp -v $D/BG_iteration_1_initialConditions/* $BG_t_RunDir
   
###enable custom coupler output
    echo 'histaux_a2x3hr = .true.' > user_nl_cpl
    echo 'histaux_a2x24hr = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hri = .true.' >> user_nl_cpl
    echo 'histaux_a2x1hr = .true.' >> user_nl_cpl
    ./xmlchange HIST_OPTION='nmonths'
    ./xmlchange HIST_N=1

###configure CAM

###configure CISM

###configure CLM
    #echo 'use_init_interp = .false.' > user_nl_clm

###configure topography updating
     CAM_topo_regen_dir=$BG_t_RunDir/dynamic_atm_topog
     if [ ! -d $CAM_topo_regen_dir ]; then
       echo 'Checking out and building topography updater...'
       gmake=/usr/bin/gmake
       trunk=https://svn-ccsm-models.cgd.ucar.edu/tools/dynamic_cam_topography/trunk
       svn co $trunk $CAM_topo_regen_dir
       cd $CAM_topo_regen_dir/phis_smoothing/definesurf
       $gmake
       cd $CAM_topo_regen_dir/bin_to_cube
       $gmake
       cd $CAM_topo_regen_dir/cube_to_target
       $gmake
 
       source $CAM_topo_regen_dir/setup.sh -r $BG_t_RunDir -p "$ProjCode" -w 00:30 -q regular
 
       cd $D/$CaseName
 
       #How to call this from new scripts?
       data_assimilation_script=$CAM_topo_regen_dir/submit_topo_regen_script.sh
       ./xmlchange DATA_ASSIMILATION=TRUE
       ./xmlchange DATA_ASSIMILATION_CYCLES=1
       ./xmlchange DATA_ASSIMILATION_SCRIPT=$data_assimilation_script
      fi       
   
###configure archiving
    ./xmlchange DOUT_S=FALSE
    
###configure submission length and restarting
    ./xmlchange STOP_OPTION='nyears'
    ./xmlchange STOP_N=1
    ./xmlchange RESUBMIT=2
    ./xmlchange JOB_QUEUE='regular'
    ./xmlchange JOB_WALLCLOCK_TIME='06:00'
    ./xmlchange PROJECT="$ProjCode"   

###make some soft links for convenience
    ln -s $BG_t_RunDir RunDir

###build
    ./case.build

###submit
    ./case.submit


