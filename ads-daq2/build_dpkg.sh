#!/bin/bash

set -e
set -x

key='<eol-prog2@eol.ucar.edu>'
eolrepo=/net/www/docs/software/debian

usage() {
    echo "Usage: ${1##*/} [-i repository ] [ -I codename ] arch"
    echo "-i: install packages with reprepro to the repository"
    echo "-I codename: install packages to $eolrepo/codename-<codename>"
    echo "arch is armel, armhf, amd64 or i386"
    echo "codename is jessie, bionic or whatever distribution has been enabled on $eolrepo"
    exit 1
}

if [ $# -lt 1 ]; then
    usage $0
fi

pkg=ads-daq2

arch=amd64

args="--no-tgz-check -sa"

while [ $# -gt 0 ]; do
    case $1 in
    -i)
        shift
        repo=$1
        ;;
    -I)
        shift
        codename=$1
        repo=$eolrepo/codename-$codename
        ;;
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
    *)
        usage $0
        ;;
    esac
    shift
done

if [ -n "$repo" ]; then
    distconf=$repo/conf/distributions
    if [ -r $distconf ]; then
        codename=$(fgrep Codename: $distconf | cut -d : -f 2)
        key=$(fgrep SignWith: $distconf | cut -d : -f 2)
        # first architecture listed
        primarch=$(fgrep Architectures: $distconf | cut -d : -f 2 | awk '{print $1}')
    fi

    if [ -z "$codename" ]; then
        echo "Cannot determine codename of repository at $repo"
        exit 1
    fi
    export GPG_TTY=$(tty)

    # Check that gpg-agent is running, and do a test signing,
    # which also caches the passphrase.
    # With gpg2 v2.1 and later, gpg-connect-agent /bye will start the
    # agent if necessary and comms are done over the standard socket:
    # $HOME/.gnupg/S.gpg-agent.
    #
    # It may contact the gpg-agent on the host over
    # the unix socket in .gnupg if many things are OK:
    #   compatible gpg2 version, same user ids, SELinux not interfering
    # With gpg2 v2.1 and later, gpg-connect-agent will start gpg-agent
    # if necessary.
    # On gpg2 v2.0 (debian jessie) one needs to start the
    # agent and use the value of GPG_AGENT_INFO that is returned to
    # determine the path to the socket.
    gpg-connect-agent /bye 2> /dev/null || eval $(gpg-agent --daemon)

    echo test | gpg2 --clearsign --default-key "$key" > /dev/null
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

if [ -n "$repo" ]; then
    umask 0002

    if ! which reprepro 2> /dev/null; then
        cmd="sudo apt-get install -y reprepro"
        echo "reprepro not found, doing: $cmd. Better yet add it to the image"
        $cmd
    fi

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


    # echo "chngs=$chngs"
    # echo "pkgs=$pkgs"
    # echo "archdebs=$archdebs"

    # Use --keepunreferencedfiles so that the previous version .deb files 
    # are not removed. Then user's who don't do an apt-get update will
    # get the old version without an error. Nightly, or once-a-week one could do
    # a deleteunreferenced.

    # try to catch the reprepro error which happens when it tries to
    # install a package version that is already in the repository.
    # This repeated-build situation can happen in jenkins if a
    # build is triggered by a pushed commit, but git pull grabs
    # an even newer commit, and a build for the newer commit is then
    # triggered later.

    # reprepro has a --ignore option with many types of errors that
    # can be ignored, but I don't see a way to ignore this error,
    # so we'll use a fixed grep.

    tmplog=$(mktemp)
    trap "{ rm -f $tmplog; }" EXIT

    for (( i=0; i < 2; i++ )); do
        status=0
        set -v
        set +e

        # For the first architecture listed in confg/distributions, install
        # all the packages listed in the changes file, including source and
        # "all" packages.
        if [ $arch == $primarch ]; then
            echo "Installing ${pkgs[*]}"
            if [ $i -gt 0 ]; then
                for p in ${pkgs[*]}; do
                    # Specifying -A $arch\|source\|all with a remove
                    # doesn't work.
                    # A package built for all archs will be placed into
                    # the repo for each architecture in the repo, but "all"
                    # is ignored in -A for the remove.  So a package for all,
                    # that is installed in the repo for amd64 won't be
                    # removed with -A i386|source|all", and you'll get
                    # a "registered with different checksums" error if
                    # you try to install it for i386. So leave -A off.
                    flock $repo sh -c "
                        reprepro -V -b $repo remove $codename $p"
                done
                flock $repo sh -c "
                    reprepro -V -b $repo deleteunreferenced"

            fi

            flock $repo sh -c "
                reprepro -V -b $repo -C main --keepunreferencedfiles include $codename $chngs" 2> $tmplog || status=$?

        # If not the first architecture listed, just install the
        # specific architecture packages.
        else
            echo "Installing $archdebs"

            if [ $i -gt 0 ]; then
                for p in ${archdebs[*]}; do
                    # remove last two underscores
                    p=${p%_*}
                    p=${p%_*}
                    flock $repo sh -c "
                        reprepro -V -b $repo -A $arch remove $codename $p"
                done
                flock $repo sh -c "
                    reprepro -V -b $repo deleteunreferenced"
            fi

            flock $repo sh -c "
                reprepro -V -b $repo -C main -A $arch --keepunreferencedfiles includedeb $codename $archdebs" 2> $tmplog || status=$?
        fi
        echo "status=$status"

        [ $status -eq 0 ] && break

        cat $tmplog
        if grep -E -q "(can only be included again, if they are the same)|(is already registered with different checksums)" $tmplog; then
            echo "One or more package versions are already present in the repository. Removing and trying again"
        fi
    done

    if [ $status -eq 0 ]; then
        rm -f ${pkg}_*_$arch.build ${pkg}_*.dsc \
            ${pkg}*_all.deb ${pkg}*_$arch.deb $chngs
        # ${pkg}_*.tar.xz \
    else
        echo "saving results in $PWD"
    fi

else
    echo "build results are in $PWD"
fi

