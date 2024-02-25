#!/bin/bash

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# first argument: arch of the executable used (you have to figure it out yourself!)
ARCH=arm64

# set up fake "jni" so that ndk-gdb can find a "valid" Android.mk
rm -rf jni && mkdir jni
echo "APP_ABI := arm64-v8a" > jni/Android.mk

