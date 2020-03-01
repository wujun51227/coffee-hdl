rm -rf out
chdl_compile.coffee --no_always_comb --iverilog -o out/always_test always_test.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/assign_simple assign_simple.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/branch_block branch_block.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/data_struct data_struct.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/default_clock default_clock.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/init_simple init_simple.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/operator_test operator_test.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/port_simple port_simple.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/reduce_test reduce_test.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/reg_simple reg_simple.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/syn_sequence_test syn_sequence_test.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/wire_simple wire_simple.chdl
