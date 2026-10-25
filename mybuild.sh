#!/bin/bash

cd $(dirname $0)/src;pwd


export package FINALPACKAGE=1
export THEOS_PACKAGE_SCHEME=roothide


if [ $1 -eq "0" ]
then
	make do
else
	make package
	mv ./packages/*.deb ~/Documents/GitHub/myTweaks/roothide/
	make clean
fi



# mv ./packages/*.deb ~/Desktop/tweaks/debs/ && make clean


# clean::
	# rm -rf .theos/obj
	# rm -rf packages