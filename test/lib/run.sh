rm -rf out
chdl_compile.coffee --no_always_comb --iverilog -o out/asyncFifo asyncFifo.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/double_sync double_sync.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/expand expand.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/fixArb fixArb.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/handshake handshake.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/lru lru.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/roundArb roundArb.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/syncFifo syncFifo.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/use_primitive_lib use_primitive_lib.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/width_expand width_expand.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/width_split width_split.chdl
