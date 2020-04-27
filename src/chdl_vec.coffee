CircuitEl = require 'chdl_el'
VecMember = require 'chdl_vec_member'
{getValue} = require 'chdl_utils'
_ = require 'lodash'

class Vec extends CircuitEl

  constructor: (width,depth)->
    super()
    @width=width
    @depth=depth
    @__type='vec'

  set: (n,expr)=>
    addr=getValue(n)
    @cell.__regAssignList.push ["assign",VecMember.create(this,addr),expr,-1]

  get: (n)->
    addr=getValue(n)
    return VecMember.create(this,addr)
    
  @create: (width,depth)-> new Vec(width,depth)

  getWidth:()=> @width

  getDepth:()=> @depth

  verilogDeclare: ()->
    return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"];"

module.exports=Vec
