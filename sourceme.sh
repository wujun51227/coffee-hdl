#!/bin/bash

if [[ $0 != $BASH_SOURCE ]]
then
  dirpath=`dirname $BASH_SOURCE`
  abspath=$(cd $dirpath && echo $PWD/${BASH_SOURCE##*/})
  export CHDL_ROOT=`dirname $abspath`
  if [[ -z "${NODE_PATH}" ]]; then
    export NODE_PATH=$CHDL_ROOT/src:$CHDL_ROOT/lib
  else
    export NODE_PATH=$CHDL_ROOT/src:$CHDL_ROOT/lib:$NODE_PATH
  fi
  export PATH=$CHDL_ROOT/bin:$CHDL_ROOT/node_modules/.bin:$PATH

  echo "==============================="
  echo "Usage:  chdl_compile.coffee [--param_file file_name] [--autoClock] -- chdl_file [--output=out_dir]"
  echo "==============================="
fi
