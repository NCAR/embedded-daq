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

export PROJECT=unknown
export AIRCRAFT=unknown

_pf_=$ADS/current_project
if [ -f $_pf_ ]; then
    PROJECT=$(<$_pf_)

    _pd_=$ADS/projects/$PROJECT

    # subdirectories of $_pd_ are the aircraft platform names
    _acs_=($(find $_pd_ -mindepth 1 -maxdepth 1 -type d))

    if [ ${#_acs_[*]} -gt 0 ]; then
        _pd_=${_acs_[0]}
        AIRCRAFT=${_pd_##*/}
    fi
    unset _acs_
    [ -d $_pd_/scripts ] && PATH=$PATH:$_pd_/scripts

    _pf_=$_pd_/scripts/dsm_env.sh
    [ -f $_pf_ ] && source $_pf_

    export CDPATH=.:$_pd_

    unset _pd_
fi
unset _pf_

