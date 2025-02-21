#!/bin/bash

cd $(dirname $0)/src;pwd
make clean
export THEOS=/Users/zqbb/theos_roothide
export  package FINALPACKAGE=1
export  THEOS_PACKAGE_SCHEME=roothide
export THEOS_DEVICE_IP=192.168.31.158
export THEOS_DEVICE_PORT=2222

if [ $1 -eq "1" ]
then
	make do
	# echo -e "sbreload" | ssh root@192.168.31.158
	exit
fi


make package

# mv ./packages/*.deb ~/Desktop/tweaks/debs/ && make clean


# clean::
	# rm -rf .theos/obj
	# rm -rf packages