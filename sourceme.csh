#!/bin/csh -f

set called=($_)
set script_fn=`readlink -f $called[2]`
set script_dir = `dirname "$script_fn"`

setenv  CHDL_ROOT $script_dir
if ($?NODE_PATH) then
  setenv  NODE_PATH $CHDL_ROOT/src:$CHDL_ROOT/lib:$CHDL_ROOT/node_modules:$NODE_PATH
else
  setenv  NODE_PATH $CHDL_ROOT/src:$CHDL_ROOT/lib:$CHDL_ROOT/node_modules
endif
setenv  PATH $CHDL_ROOT/bin:$CHDL_ROOT/node_modules/.bin:$PATH

echo "==============================="
echo "chdl_compile.coffee ready"
echo "==============================="
