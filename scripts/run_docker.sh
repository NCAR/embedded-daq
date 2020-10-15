#!/bin/sh

# Start a Docker container to build debian packages

defuser=ads
defgroup=eol

user=$defuser
group=$defgroup

usage() {
    echo "usage: ${0##*/} [-u user] [-g group] [ armel | armhf | armbe | vortex ]

    viper and titan are armel, rpi2 is armhf and vulcan is armbe

If user id is numeric and not in /etc/passwd inside the container, you'll see a prompt of \"I have no name\", which isn't generally fatal. If it is a string and not in /etc/passwd, docker will fail.

The user in the container should have have write permission on the file systems that are bind mounted in the container, which includes this nidas tree. If is often easiest to make everything writable by the group.

Default user: $defuser, default group: $defgroup"
    exit 1
}

while [ $# -gt 0 ]; do

case $1 in
    armel | viper | titan)
        image=ncar/nidas-build-debian-armel:jessie_v1
        ;;
    armhf | rpi2)
        image=ncar/nidas-build-debian-armhf:jessie_v1
        ;;
    armbe | vulcan)
        image=maclean/fedora25-armbe-cross:ael
        ;;
    vortex)
        image=docker.io/ncar/ubuntu-i386:xenial
        ;;
    -u)
        shift
        [ $# -lt 1 ] && usage
        user=$1
        ;;
    -g)
        shift
        [ $# -lt 1 ] && usage
        group=$1
        ;;
esac
    shift
done

[ -z $image ] && usage

selinuxenabled && [ $(getenforce) == Enforcing ] && zopt=,Z

# The source tree is the parent of the directory containing this script.
# It will be bind mounted to ~/$tdir in the Docker container.

dir=$(dirname $0)
cd $dir/..
tdir=$(basename $PWD)

nowrite=$(find . \( \! -perm /020 -o \! -group $group \) -print -quit)
[ -n "$nowrite" ] && echo "Warning, some files in $PWD don't have $group group write access. Do \"chgrp -R $group $PWD; chmod -R g+ws $PWD\""

# If the image is not already loaded, docker run will pull the image from
# the Docker Hub.

repo=/net/ftp/pub/archive/software/debian
if [ -d $repo ]; then
    echo "$repo found, mounting to docker container"
    repoopt="--volume $repo:$repo:rw$zopt"
fi

echo "Running container as user $user. If it isn't listed in /etc/passwd in the container, you'll have a \"I have no name\" prompt, but it isn't necessarily a fatal problem."
echo "Running container as group $group, which must have rwx permission on $PWD"
[ -n "$repoopt" ] && echo "and $repo"

set -x
exec docker run --rm --user $user:$group \
    --volume $PWD:/home/builder/$tdir:rw$zopt \
    $repoopt \
    --network=host \
    -i -t $image /bin/bash

