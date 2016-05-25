#!/bin/echo You must source 

# If not set, set ISFS to the parent of the directory
# containing this script.
if ! [ $ISFS ]; then
    _pd_=${BASH_SOURCE[0]%/*}
    _pd_=$(readlink -f ${_pd_:-.})
    export ISFS=${_pd_%/*}
    unset _pd_
fi

echo $PATH | grep -qF $ISFS/bin || PATH=$PATH:$ISFS/bin
echo $PATH | grep -qF /opt/nidas/bin || PATH=$PATH:/opt/nidas/bin

_pf_=$ISFS/current_project
if [ -f $_pf_ ]; then
    export PROJECT=$(<$_pf_)

    _pd_=$ISFS/projects/$PROJECT/ISFS
    if [ ! -d $_pd_ ]; then
        _pd_=($ISFS/projects/$PROJECT/*)
         _pd_=${_pd_[0]}
    fi
    [ -d $_pd_/scripts ] && PATH=$PATH:$_pd_/scripts

    _pf_=$_pd_/scripts/dsm_env.sh
    [ -f $_pf_ ] && source $_pf_ || echo "$_pf_ not found. Cannot setup project environment."

    export CDPATH=.:$_pd_:$DATAMNT/projects/$PROJECT

    [ $DATAMNT ] && export CDPATH=$CDPATH:$DATAMNT/projects/$PROJECT

    unset _pd_
else
    echo "$_pf_ not found. Cannot setup project environment."
fi
unset _pf_

