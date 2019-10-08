CircuitEl = require 'chdl_el'
Reg = require 'chdl_reg'
_ = require 'lodash'
{packEl,toNumber}=require 'chdl_utils'

class Vec extends CircuitEl

  constructor: (width,depth)->
    super()
    @width=width
    @depth=depth
    @bin=(Reg.create(width) for i in [0...depth])
    for i in @bin
      i.setMem()

  index: (n)->
    if n.constructor?.name=='Expr'
      return packEl('reg',@bin[Number(n.str)])
    else if _.isNumber(n)
      return packEl('reg',@bin[n])
    else if _.isFunction(n)
      reg=Reg.create(@width)
      reg.link(@cell, @elName+'['+n().elName+']')
      reg.setMem()
      return packEl('reg',reg)
    else
      reg=Reg.create(@width)
      reg.link(@cell, @elName+'['+n.elName+']')
      reg.setMem()
      return packEl('reg',reg)

  link: (cell,name)->
    @cell=cell
    @elName=name
    for i,index in @bin
      i.link(cell,name+'['+index+']')

  refName: -> @elName

  @create: (width,depth)-> new Vec(width,depth)

  verilogDeclare: ()->
    return "reg ["+(@width-1)+":0] "+@elName+"[0:"+(@depth-1)+"];"

module.exports=Vec
