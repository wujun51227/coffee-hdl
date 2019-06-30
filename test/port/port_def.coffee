{input,output} = require 'chdl_base'

out_port={
  enable: output()
  dout: output(5)
}

in_port={
  enable: input()
  din: input(5)
}

module.exports.in_port = in_port
module.exports.out_port = out_port
