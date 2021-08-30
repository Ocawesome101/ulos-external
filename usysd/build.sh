#!/bin/bash

#imods=$(echo $IMODS | sed 's/,/\n/g')

#rm -f includes.lua
#touch includes.lua

#for mod in $imods; do
#  printf "including module $mod\n"
#  echo "--#include \"$mod.lua\"" >> includes.lua
#done

rm -rf out && mkdir -p out/sbin
$PREPROCESSOR init.lua out/sbin/init.lua
#rm -f includes.lua
