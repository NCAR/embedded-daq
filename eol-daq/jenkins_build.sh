#!/bin/bash

# Build debian package if anything has changed.
# The method for checking if anything has changed
# is to create a tar file of all the files in the
# current directory, and check if its md5sum has
# changed since the last run

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

tar cf $tmptar --mtime="2010-01-01 00:00" --exclude=.gitignore .

if ! check_md5 - < $tmptar > /dev/null; then
    ./build_dpkg.sh -s -r $repo && save_md5 - < $tmptar
else
    echo "No changes since last build"
fi

