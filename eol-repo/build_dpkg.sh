#!/bin/bash

# avoid dpkg commands on /opt/arcom/bin
PATH=/usr/bin:$PATH

umask 0020

dpkg=eol-repo

set -e

key='<eol-prog@eol.ucar.edu>'

# From /etc/os-release, read VERSION_CODENAME
[ -r /etc/os-release ] && source /etc/os-release

usage() {
    echo "Usage: ${1##*/} [-s] [-r] [-c codename ] [dest]
    -s: sign the package files with $key
    -r: run reprepro to install .deb to dest
    -R: run reprepro and set dest to /net/ftp/pub/archive/software/debian
    -c codename: codename to use when installing with reprepro
    dest: destination, default is .
    Default codename: $VERSION_CODENAME, from \$VERSION_CODENAME in /etc/os-release"
   
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
    -R)
        reprepro=true
        dest=/net/ftp/pub/archive/software/debian
        ;;
    -c)
        shift
        [ $# -lt 1 ] && usage
        VERSION_CODENAME=$1
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

    if [ -z $VERSION_CODENAME ]; then
	# From /etc/os-release, read VERSION_CODENAME
	[ -r /etc/os-release ] && source /etc/os-release
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
    set -x
    # copy package to top of repository, as simply eol-repo.deb
    # to make it easier for users to do the initial install
    cp $newname $dest/$dpkg.deb
    # if includedeb command fails, remove the package, try again
    for (( i=0; i < 2; i++ )); do
	flock $dest sh -c "
	    reprepro -V -b $dest --keepunreferencedfiles includedeb $VERSION_CODENAME $newname" && echo $this_hash > $hashfile
	[ $status -eq 0 ] && break
	flock $dest sh -c "reprepro -V -b $dest remove $VERSION_CODENAME eol-repo"
    done
else
    echo "moving $newname to $dest"
    mv $newname $dest
fi

