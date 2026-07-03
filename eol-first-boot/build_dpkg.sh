#!/bin/bash

# avoid dpkg commands on /opt/arcom/bin
PATH=/usr/bin:$PATH

dpkg=eol-first-boot

set -e

key='<eol-prog2@eol.ucar.edu>'

usage() {
    echo "Usage: ${1##*/} [dest]"
    echo "dest: destination, default is ."
    exit 1
}

dest=
while [ $# -gt 0 ]; do
    case $1 in
    -h)
        usage
        ;;
    -*)
        usage $0
        ;;
    *)
        if [ -n "$dest" ]; then
            usage $0
        fi
        dest=$1
        ;;
    esac
    shift
done
if [ -z "$dest" ]; then
    dest=$PWD
fi

script=$0
script=${script##*/}

# directory containing script
srcdir=$(readlink -f ${0%/*})
hashfile=$srcdir/.last_hash
cd $srcdir

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

echo "moving $newname to $dest"
mv $newname $dest
