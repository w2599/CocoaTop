#!/bin/bash

cd $(dirname $0);pwd
cd src
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

mv ./packages/*.deb ~/Desktop/tweaks/rootless/ && make clean





# clean ::
	# rm -rf .theos
	# rm -rf packages
	