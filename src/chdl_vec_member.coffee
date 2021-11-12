CircuitEl = require 'chdl_el'
{toSignal} = require('chdl_utils')

class VecMember extends CircuitEl

  constructor: (vec,index,width)->
    super()
    @width=width
    @index=index
    @vec=vec

  @create: (vec,index)-> new VecMember(vec,index,vec.getWidth())

  getWidth: -> @width

  refName: -> @vec.getName()+'['+@index+']'

  getElId: => @vec.getElId()

module.exports=VecMember
