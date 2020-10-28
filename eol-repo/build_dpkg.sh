#!/bin/bash

script=$0
script=${script##*/}

# avoid dpkg commands on /opt/arcom/bin
PATH=/usr/bin:$PATH

umask 0020

dpkg=eol-repo

set -e

repobase=/net/ftp/pub/archive/software/debian

# directory containing this build_dpkg.sh script
srcdir=$(readlink -f ${0%/*})
cd $srcdir

usage() {
    echo "Usage: ${1##*/} [-i repository ] [-I codename ] [dest]
    -i repository: install packages with reprepro to the repository
    -I codename: install packages to $repobase/codename-<codename>
    dest: destination if not installing with reprepro, default is $PWD
    For example to put packages on EOL ubuntu xenial repository:
    $0 -s -I xenial"
    exit 1
}

dest=.
reprepro=false
while [ $# -gt 0 ]; do
    case $1 in
    -h)
        usage
        ;;
    -i)
        reprepro=true
        shift
        [ $# -lt 1 ] && usage
        repo=$1
        ;;
    -I)
        reprepro=true
        shift
        [ $# -lt 1 ] && usage
        repo=$repobase/codename-$1
        ;;
    *)
        dest=$1
        ;;
    esac
    shift
done

if $reprepro; then
    distconf=$repo/conf/distributions
    if [ -r $distconf ]; then
        codename=$(fgrep Codename: $distconf | cut -d : -f 2)
        codename=${codename## } # remove leading spaces
    fi

    if [ -z "$codename" ]; then
        echo "Cannot determine codename of repository at $repo"
        exit 1
    fi
    hashfile=$srcdir/.last_hash_$codename
    [ -f $hashfile ] && last_hash=$(cat $hashfile)
    this_hash=$(git log -1 --format=%H .)
    if [ "$this_hash" == "$last_hash" ]; then
        echo "No updates in $PWD since last build"
        echo "Remove $hashfile to force a build"
        exit 0
    fi

    export GPG_TTY=$(tty)
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

if $reprepro; then
    set -x
    set +e  # dont error out
    # copy package to top of repository, as simply eol-repo.deb
    # to make it easier for users to do the initial install
    cp $newname ${repo%/*}/$dpkg.deb

    # if includedeb command fails, remove the package, try again
    for (( i=0; i < 2; i++ )); do
        flock $repo sh -c "
            reprepro -V -b $repo includedeb $codename $newname"
        if [ $? -eq 0 ]; then
            echo $this_hash > $hashfile
            break
        fi
        flock $repo sh -c "reprepro -V -b $repo remove $codename eol-repo"
        flock $repo sh -c "reprepro -V -b $repo deleteunreferenced"
    done
else
    echo "moving $newname to $dest"
    mv $newname $dest
fi

