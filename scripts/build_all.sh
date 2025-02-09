#!/bin/bash

# Jenkins lands in /root, so allow us to pass in a directory to build from.
if [ -n "$1" ]; then
  cd $1
fi

export PATH=scripts:$PATH

for dir in ads-daq ads-daq2 eol-daq eol-repo
do
  echo '------------------------------------------------------------------------------------------'
  cd $dir;
  pwd
  ./build_dpkg.sh -I bionic i386
  cd ..
done
