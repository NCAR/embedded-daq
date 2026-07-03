#!/bin/bash

set -e
set -x

usage() {
    echo "Usage: ${1##*/} arch [dest]"
    echo "arch is armel, armhf, amd64 or i386"
    echo "dest: destination default is $PWD"
    exit 1
}

if [ $# -lt 1 ]; then
    usage $0
fi

pkg=ads-daq2

arch=amd64

args="--no-tgz-check -sa"

dest=
while [ $# -gt 0 ]; do
    case $1 in
    armel)
        export CC=arm-linux-gnueabi-gcc
        arch=$1
        ;;
    armhf)
        export CC=arm-linux-gnueabihf-gcc
        arch=$1
        ;;
    amd64)
        arch=$1
        ;;
    i386)
        arch=$1
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

args="$args -a$arch"

sdir=$(realpath $(dirname $0))

cd $sdir

# create changelog
$sdir/deb_changelog.sh $pkg > debian/changelog

args="$args -us -uc"

# clean old results
rm -f ../${pkg}_*.dsc
rm -f $(echo ../${pkg}\*_{$arch,all}.{deb,build,changes})

# export DEBUILD_DPKG_BUILDPACKAGE_OPTS="$args"

# dpkg-source --commit . git-changes

debuild $args \
        --lintian-opts --suppress-tags dir-or-file-in-opt,package-modifies-ld.so-search-path,package-name-doesnt-match-sonames

# debuild puts results in parent directory
cd ..

echo "Build results:"
ls
echo ""

chngs=${pkg}_*_$arch.changes 
# display changes file
echo "Contents of $chngs"
cat $chngs
echo ""

archdebs=${pkg}*$arch.deb

# Grab all the package names from the changes file
pkgs=($(awk '/Checksums-Sha1/,/Checksums-Sha256/ { if (NF > 2) print $3 }' $chngs | grep ".*\.deb" | sed "s/_.*_.*\.deb//"))
echo $pkgs

mv ${pkgs}_* ${pkgs}-dbgsym_* $dest
echo "build results are in $dest"
