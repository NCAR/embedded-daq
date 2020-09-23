#!/bin/bash

script=$0
script=${script##*/}

# avoid dpkg commands on /opt/arcom/bin
PATH=/usr/bin:$PATH

umask 0020

dpkg=eol-repo

set -e

key='<eol-prog@eol.ucar.edu>'

codenames=(jessie xenial)

# directory containing this build_dpkg.sh script
srcdir=$(readlink -f ${0%/*})
hashfile=$srcdir/.last_hash
cd $srcdir

eolrepo=/net/ftp/pub/archive/software/debian

usage() {
    echo "Usage: ${1##*/} [-s] [-r] [-R] [dest]
    -s: sign the package files with $key
    -r: run reprepro to install .deb to dest
    -R: run reprepro and set dest to $eolrepo
    dest: destination, default is $PWD

    With -r or -R, packages will be installed to dest/code-name*\$codename
    for codenames in ${codenames[*]}"
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
        dest=$eolrepo
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

if $reprepro; then
    [ -f $hashfile ] && last_hash=$(cat $hashfile)
    this_hash=$(git log -1 --format=%H .)
    if [ "$this_hash" == "$last_hash" ]; then
        echo "No updates in $PWD since last build"
        exit 0
    fi
    if [ $dest != $eolrepo ]; then
        for codename in ${codenames[*]}; do
            mkdir -p $dest/codename-$codename
        done
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
    set +e  # don't error out
    # copy package to top of repository, as simply eol-repo.deb
    # to make it easier for users to do the initial install
    cp $newname $dest/$dpkg.deb
    for codename in ${codenames[*]}; do
        # if includedeb command fails, remove the package, try again
        for (( i=0; i < 2; i++ )); do
            flock $dest sh -c "
                reprepro -V -b $dest/codename-$codename includedeb $codename $newname"
            if [ $? -eq 0 ]; then
                echo $this_hash > $hashfile
                break
            fi
            flock $dest sh -c "reprepro -V -b $dest/codename-$codename remove $codename eol-repo"
        done
    done
else
    echo "moving $newname to $dest"
    mv $newname $dest
fi

