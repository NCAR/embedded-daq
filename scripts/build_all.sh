#!/bin/bash

for dir in ads-daq ads-daq2 eol-daq eol-repo
do
  cd $dir;
  ./build_dpkg.sh -I bionic i386;
  cd ..
done

