CircuitEl = require 'chdl_el'
VecMember = require 'chdl_vec_member'
_ = require 'lodash'

class Vec extends CircuitEl

  constructor: (width,depth)->
    super()
    @width=width
    @depth=depth
    @__type='vec'

  set: (n,expr)=>
    addr=0
    if n.constructor?.name=='Expr'
      addr=Number(n.str)
    else if _.isNumber(n)
      addr=n
    else if _.isFunction(n)
      addr=n().hier
    else
      addr=n.hier
    @cell.__regAssignList.push ["assign",VecMember.create(this,addr),expr,-1]

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
    return VecMember.create(this,addr)
    
  @create: (width,depth)-> new Vec(width,depth)

  getWidth:()=> @width

  verilogDeclare: ()->
    return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"];"

module.exports=Vec
