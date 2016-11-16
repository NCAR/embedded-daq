#!/bin/bash

# avoid dpkg commands on /opt/arcom/bin
PATH=/usr/bin:$PATH

dpkg=eol-daq

set -e

key='<eol-prog@eol.ucar.edu>'

usage() {
    echo "Usage: ${1##*/} [-s] [-r] [dest]"
    echo "-s: sign the package files with $key"
    echo "-r: run reprepro to install .deb to dest"
    echo "dest: destination, default is ."
    exit 1
}

dest=.
sign=false
reprepro=false
while [ $# -gt 0 ]; do
    case $1 in
    -h)
        usage
        ;;
    -r)
        reprepro=true
        ;;
    -s)
        sign=true
        ;;
    *)
        dest=$1
        ;;
    esac
    shift
done

script=$0
script=${script##*/}

# directory containing script
srcdir=$(readlink -f ${0%/*})
hashfile=$srcdir/.last_hash
cd $srcdir

if $reprepro; then
    [ -f $hashfile ] && last_hash=$(cat $hashfile)
    this_hash=$(git log -1 --format=%H .)
    if [ "$this_hash" == "$last_hash" ]; then
        echo "No updates in $PWD since last build"
        exit 0
    fi
fi

# what to rsync into package: all subdirectories
pkgdirs=($(find . -mindepth 1 -maxdepth 1 -type d))

if gitdesc=$(git describe --match "v[0-9]*"); then
    # example output of git describe: v2.0-14-gabcdef123
    gitdesc=${gitdesc/#v}       # remove leading v
    version=${gitdesc%-g*}       # 2.0-14
else
    echo "git describe failed, looking for a tag of the form v[0-9]*"
    version="1.0-1"
    # exit 1
fi

tmpdir=$(mktemp -d /tmp/${0##*/}_XXXXXX)
trap "{ rm -rf $tmpdir; }" EXIT
pdir=$tmpdir/$dpkg
mkdir -p $pdir

rsync --exclude=.gitignore -a ${pkgdirs[*]} $pdir

pushd $pdir
# Do shell syntax checking of package scripts
for sf in $(find DEBIAN -type f -perm /111); do
    shell=$(sed -r -n '1s/^#\!//p' $sf)
    if [ -n "$shell" ]; then
        $shell -n $sf || exit 1
    fi
done
popd

# create man pages from docbook xml files
cf=$pdir/usr/share/man
pushd manpages
for d in $(find . -mindepth 1 -maxdepth 1 -type d ); do
    pushd $d
    for x in *.xml; do
        xmlto man -o $cf/$d $x
        gzip $cf/$d/${x%.xml}
    done
    popd
done
popd

cf=$pdir/usr/share/doc/$dpkg/changelog.Debian.gz
cd=${cf%/*}
[ -d $cd ] || mkdir -p $cd

cat << EOD | gzip -c -9 > $cf
$dpkg Debian maintainer and upstream author are identical.
Therefore see also normal changelog file for Debian changes.
EOD

# output gzipped git log to usr/share/doc/eol-daq

sed -i -e "s/^Version:.*/Version: $version/" $pdir/DEBIAN/control

chmod -R g-ws $pdir/DEBIAN

fakeroot dpkg-deb -b $pdir

# dpkg-name: info: moved 'eol-daq.deb' to '/tmp/build_dpkg.sh_4RI6L9/eol-daq_1.0-1_all.deb'
newname=$(dpkg-name ${pdir%/*}/${dpkg}.deb | sed -r -e "s/.* to '([^']+)'.*/\1/")

if $sign; then
    if [ -e $HOME/.gpg-agent-info ]; then
        export GPG_AGENT_INFO
        . $HOME/.gpg-agent-info
        dpkg-sig -k "$key" --gpg-options "--batch --no-tty" --sign builder $newname
    else
        echo "Warning: $HOME/.gpg-agent-info not found"
        dpkg-sig --sign builder -k "$key" $newname
    fi
fi

if $reprepro; then
    # remove _debver_all.deb from names of packages passed to reprepro
    pkg=${newname##*/}
    pkg=${pkg%_*}
    pkg=${pkg%_*}
    flock $dest sh -c "
        # reprepro -V -b $dest remove jessie $pkg
        # reprepro -V -b $dest deleteunreferenced
        reprepro -V -b $dest includedeb jessie $newname" && echo $this_hash > $hashfile
else
    echo "moving $newname to $dest"
    mv $newname $dest
fi

