#!/bin/echo You must source 

# If not set, set ADS to the parent of the directory
# containing this script.
if ! [ $ADS ]; then
    _pd_=${BASH_SOURCE[0]%/*}
    _pd_=$(readlink -f ${_pd_:-.})
    export ADS=${_pd_%/*}
    unset _pd_
fi

echo $PATH | grep -qF $ADS/bin || PATH=$PATH:$ADS/bin

_pf_=$ADS/current_project
if [ -f $_pf_ ]; then
    export PROJECT=$(<$_pf_)

    _pd_=$ADS/projects/$PROJECT

    # subdirectories of $_pd are the aircraft platform names
    _pds=($(find $_pd -maxdepth 1 -mindepth 1 -type d))
    # could be more than one aircraft configured
    [ ${#_pds[*]} -gt 0 ] && _pd_=${_pds[0]}
    unset _pds
    [ -d $_pd_/scripts ] && PATH=$PATH:$_pd_/scripts

    _pf_=$_pd_/scripts/dsm_env.sh
    [ -f $_pf_ ] && source $_pf_ || echo "$_pf_ not found. Cannot setup project environment."

    export CDPATH=.:$_pd_:$DATAMNT/projects/$PROJECT

    unset _pd_
fi
unset _pf_

