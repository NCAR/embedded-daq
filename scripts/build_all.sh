#!/bin/bash

# This script runs from the top of the source tree and provides methods to
# build all packages and to upload them to the Debian repository.  It is
# similar to a jenkins.sh script in other repos.

upload_packages="$HOME/eol-repo/scripts/upload_packages.sh"
pkgdir=build-packages

# Run all the build_dpkg.sh scripts in the Debian container, starting from a
# specific working directory if given.  All the packages are moved to the
# build-packages subdirectory.
build_all() # workdir
{
    # Jenkins lands in /root, so allow us to pass in a directory to build from.
    if [ -n "$1" ]; then
        cd $1
    fi

    rm -rf $pkgdir
    mkdir -p $pkgdir

    for dir in ads-daq ads-daq2 eol-daq ; do
        echo '------------------------------------------------------------------------------------------'
        cd $dir;
        pwd
        ./build_dpkg.sh i386 $(realpath ../$pkgdir)
        cd ..
    done
}


# Run the build_all function inside the container
build()
{
    # Add a default nidas install to the PATH in case not found elsewhere.
    export PATH=${PATH}:/opt/nidas/bin
    start_podman bionic "/root/current/scripts/build_all.sh build_all /root/current"
}


upload()
{
    $upload_packages codename=bionic upload ./$pkgdir
}


case "$1" in
    build)
        shift
        build "$@"
        ;;
    upload)
        shift
        upload "$@"
        ;;
    build_all)
        shift
        build_all "$@"
        ;;
    *)
        echo "Usage: $0 build|upload"
        ;;
esac
