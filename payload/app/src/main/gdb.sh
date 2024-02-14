#!/bin/bash

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

# first argument: arch of the executable used (you have to figure it out yourself!)
ARCH=${ARCH}

# set up fake "jni" so that ndk-gdb can find a "valid" Android.mk
rm -rf jni && mkdir jni
echo "APP_ABI := ${ABI}" > jni/Android.mk

rm -f gdb.exec
echo "shell rm -rf jni" >> gdb.exec
echo "set solib-search-path ../$ABI/" >> gdb.exec
echo "set history save on" >> gdb.exec
echo "set breakpoint pending on" >> gdb.exec

ndk-gdb --attach is.xyz.omw_nightly.debug -x "gdb.exec"
