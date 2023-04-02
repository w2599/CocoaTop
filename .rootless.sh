#!/bin/bash

cd $(dirname $0);pwd
cd src
make clean
export THEOS_PACKAGE_SCHEME=rootless
make package FINALPACKAGE=1

mv ./packages/*.deb ~/Desktop/tweaks/rootless/ && make clean


# clean ::
	# rm -rf .theos
	# rm -rf packages
	