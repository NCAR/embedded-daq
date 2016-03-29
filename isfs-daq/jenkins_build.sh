#!/bin/bash

# Build debian package if anything has changed.
# The method for checking if anything has changed
# is to create a tar file of the files that go
# into the package, along with the scripts that create it,
# using the --mtime option so that the file modification
# times in the tar-ball do not change. Compute the md5sum
# of the tar-ball, and it is has changed, or the previous
# md5sum does not exist, then build the package.
# If the build succeeds, then save the md5sum
# of the tar-ball in this directory.

# A weakness here is that we need to do the md5sum
# check on the files in the package. The build_dpkg.sh
# script uses rsync to copy the files to a temporary
# directory, this script uses tar. As long as they include
# the same set of files we're OK.

pkgcontents=(DEBIAN home)

if [ $# -lt 1 ]; then
    echo "Usage: ${0##*/} repository"
    exit 1
fi
repo=$1

set -e

check_md5() {
    local file=$1
    local sumfile=.${file}_md5sum
    md5sum --quiet --check $sumfile 2>/dev/null
    return $?
}
save_md5() {
    local file=$1
    local sumfile=.${file}_md5sum
    md5sum $file > $sumfile
}

tmptar=$(mktemp /tmp/${0##*/}_XXXXXX.tar)
trap "{ rm -f $tmptar; }" EXIT

tar cf $tmptar --mtime="2010-01-01 00:00" --exclude=.gitignore ${pkgcontents[*]} *.sh

if ! check_md5 - < $tmptar > /dev/null; then
    ./build_dpkg.sh -s -r $repo && save_md5 - < $tmptar
else
    echo "No changes since last build"
fi

