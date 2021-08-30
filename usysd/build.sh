#!/bin/bash

rm -rf out && mkdir -p out/sbin
$PREPROCESSOR init.lua out/sbin/init.lua
cp -r files/* out/
