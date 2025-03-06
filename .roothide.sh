#!/bin/bash

cd $(dirname $0)/src;pwd

export THEOS=/Users/zqbb/theos_roothide
export package FINALPACKAGE=1
export THEOS_PACKAGE_SCHEME=roothide
export THEOS_DEVICE_IP=192.168.31.158
export THEOS_DEVICE_PORT=2222


if [ $1 -eq "1" ]
then
	make do
	make clean
	exit
fi


make package
mv ./packages/*.deb ~/Documents/GitHub/myTweaks/roothide/
make clean
# mv ./packages/*.deb ~/Desktop/tweaks/debs/ && make clean


# clean::
	# rm -rf .theos/obj
	# rm -rf packages