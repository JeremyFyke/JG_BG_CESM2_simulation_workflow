#!/bin/bash

CESM_CaseName=b.e20.B1850.f09_g17.pi_control.all.149.cism
CESM_SD=/glade/p/cesmdata/cseg/inputdata/ccsm4_init/$CESM_CaseName/0103-01-01

###Link to all non-CISM restart files/rpointers
    for f in `ls "$CESM_SD"/"$CESM_CaseName"*`; do
      if ! echo $f | grep --quiet 'cism.r.'; then
         echo Linking $f
         ln -sf $f ./`basename $f`
      fi
    done

    for f in rpointer.atm \
             rpointer.drv \
	     rpointer.ice \
	     rpointer.lnd \
	     rpointer.ocn.ovf \
	     rpointer.ocn.restart \
	     rpointer.rof; do
      ln -sf $CESM_SD/$f ./$f
    done
    
###Separately link all non-CISM restart files/rpointers
    for f in `ls "$CESM_SD"/"$CESM_CaseName"*cism.r.*`; do
      echo Linking $f
      ln -sf $f ./`basename $f`
    done    
    ln -sf $CESM_SD/rpointer.glc ./rpointer.glc
    


