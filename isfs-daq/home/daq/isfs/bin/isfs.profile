#!/bin/echo You must source 

_pf_=$ISFS/current_project
if [ -f $_pf_ ]; then
    export PROJECT=$(<$_pf_)

    _pd_=$ISFS/projects/$PROJECT/ISFS
    if [ ! -d $_pd_ ]; then
        _pd_=($ISFS/projects/$PROJECT/*)
         _pd_=${_pd_[0]}
    fi
    [ -d $_pd_/scripts/dsm ] && PATH=$PATH:$_pd_/scripts/dsm

    _pf_=$_pd_/scripts/dsm/dsm_env.sh
    [ -f $_pf_ ] && source $_pf_ || echo "$_pf_ not found. Cannot setup project environment."

    export CDPATH=.:$_pd_:$DATAMNT/projects/$PROJECT

    [ $DATAMNT ] && export CDPATH=$CDPATH:$DATAMNT/projects/$PROJECT

    unset _pd_
else
    echo "$_pf_ not found. Cannot setup project environment."
 fi
 unset _pf_

