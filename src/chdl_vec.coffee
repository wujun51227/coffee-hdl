CircuitEl = require 'chdl_el'
Reg = require 'chdl_reg'
_ = require 'lodash'
{packEl,toNumber}=require 'chdl_utils'

class Vec extends CircuitEl

  constructor: (width,depth)->
    super()
    @width=width
    @depth=depth
    @__type='vec'

  set: (n,data)=>
    addr=0
    if n.constructor?.name=='Expr'
      addr=Number(n.str)
    else if _.isNumber(n)
      addr=n
    else if _.isFunction(n)
      addr=n().hier
    else
      addr=n.hier
    @cell.verilog(@elName+"[#{addr}] = #{data};")

  get: (n)->
    addr=0
    if n.constructor?.name=='Expr'
      addr=Number(n.str)
    else if _.isNumber(n)
      addr=n
    else if _.isFunction(n)
      addr=n().hier
    else
      addr=n.hier
    return @elName+"[#{addr}]"
    
  @create: (width,depth)-> new Vec(width,depth)

  verilogDeclare: ()->
    return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"];"

module.exports=Vec
