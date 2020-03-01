rm -rf out
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_autobind channel_autobind.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_bind_extend channel_bind_extend.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_bind_port channel_bind_port.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_connect channel_connect.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_hub_connection channel_hub_connection.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_port_array_hub channel_port_array_hub.chdl
chdl_compile.coffee --no_always_comb --iverilog -o out/channel_probe channel_probe.chdl
